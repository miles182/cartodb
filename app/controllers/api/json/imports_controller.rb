#encoding: UTF-8

require_relative '../../../../services/datasources/lib/datasources'

class Api::Json::ImportsController < Api::ApplicationController

  include FileUploadHelper

  ssl_required :index, :show, :create
  ssl_allowed :service_token_valid?, :list_files_for_service, :get_service_auth_url, :validate_service_oauth_code,
              :invalidate_service_token, :service_oauth_callback
  respond_to :html, only: [:get_service_auth_url]

  # NOTE: When/If OAuth tokens management is built into the UI, remove this to send and check CSRF
  skip_before_filter :verify_authenticity_token, only: [:invalidate_service_token, :service_oauth_callback]

  INVALID_TOKEN_MESSAGE = 'OAuth token invalid or expired'

  # -------- Import process -------

  def index
    imports = current_user.importing_jobs
    render json: { imports: imports.map(&:id), success: true }
  end

  def show
    data_import = DataImport[params[:id]]
    data_import.mark_as_failed_if_stuck!

    data = data_import.reload.public_values.except('service_item_id', 'service_name')
    if data_import.state == DataImport::STATE_COMPLETE
      data[:any_table_raster] = data_import.is_raster?

      if data_import.service_name == CartoDB::Datasources::Search::Twitter::DATASOURCE_NAME

      audit_entry = ::SearchTweet.where(data_import_id: data_import.id).first

      data[:tweets_georeferenced] = audit_entry.retrieved_items
      data[:tweets_cost] = audit_entry.price
      data[:tweets_overquota] = audit_entry.user.remaining_twitter_quota == 0
      end
    end

    render json: data
  end

  def create
    if params[:url].present?
      file_uri = params[:url]
      enqueue_importer_task = true
    else
      results = upload_file_to_storage(params, request, Cartodb.config[:importer]['s3'])
      file_uri = results[:file_uri]
      enqueue_importer_task = results[:enqueue]
    end

    service_name =
      params[:service_name].present? ? params[:service_name] : CartoDB::Datasources::Url::PublicUrl::DATASOURCE_NAME
    service_item_id = params[:service_item_id].present? ? params[:service_item_id] : params[:url].presence

    options = {
        user_id:                current_user.id,
        table_name:             params[:table_name].presence,
        # Careful as this field has rules (@see DataImport data_source=)
        data_source:            file_uri.presence,
        table_id:               params[:table_id].presence,
        append:                 (params[:append].presence == 'true'),
        table_copy:             params[:table_copy].presence,
        from_query:             params[:sql].presence,
        service_name:           service_name.presence,
        service_item_id:        service_item_id.presence,
        type_guessing:          params.fetch(:type_guessing, true),
        quoted_fields_guessing: params.fetch(:quoted_fields_guessing, true),
        content_guessing:       ["true", true].include?(params[:content_guessing]),
        state:                  enqueue_importer_task ? DataImport::STATE_PENDING : DataImport::STATE_ENQUEUED,
        upload_host:            Socket.gethostname
    }

    data_import = DataImport.create(options)

    Resque.enqueue(Resque::ImporterJobs, job_id: data_import.id) if enqueue_importer_task

    render_jsonp({ item_queue_id: data_import.id, success: true })
  end

  # ----------- Import OAuths Management -----------

  def service_token_valid?
    oauth = current_user.oauths.select(params[:id])

    return render_jsonp({ oauth_valid: false, success: true }) if oauth.nil?
    datasource = oauth.get_service_datasource
    return render_jsonp({ oauth_valid: false, success: true }) if datasource.nil?
    unless datasource.kind_of? CartoDB::Datasources::BaseOAuth
      raise CartoDB::Datasources::InvalidServiceError.new("Datasource #{params[:id]} does not support OAuth")
    end

    begin
      valid = datasource.token_valid?
    rescue CartoDB::Datasources::DataDownloadError
      valid = false
    end

    unless valid
      begin
        current_user.oauths.remove(params[:id])
      rescue
        # Just remove it if was present, no need to do anything
      end
    end

    render_jsonp({ oauth_valid: valid, success: true })
  rescue CartoDB::Datasources::TokenExpiredOrInvalidError => ex
    begin
      current_user.oauths.remove(ex.service_name)
    rescue
      # Just remove it if was present, no need to do anything
    end
    render_jsonp({ errors: { imports: INVALID_TOKEN_MESSAGE } }, 401)
  rescue => ex
    begin
      current_user.oauths.remove(ex.service_name)
    rescue
      # Just remove it if was present, no need to do anything
    end
    CartoDB::Logger.info('Error: service_token_valid?', "#{ex.message} #{ex.backtrace.inspect}")
    render_jsonp({ errors: { imports: ex.message } }, 400)
  end

  def list_files_for_service
    # @see CartoDB::Datasources::Base::FORMAT_xxxx constants
    filter = params[:filter].present? ? params[:filter] : []

    oauth = current_user.oauths.select(params[:id])
    raise CartoDB::Datasources::AuthError.new("No oauth set for service #{params[:id]}") if oauth.nil?
    datasource = oauth.get_service_datasource
    raise CartoDB::Datasources::AuthError.new("Couldn't fetch datasource for service #{params[:id]}") if datasource.nil?

    results = datasource.get_resources_list(filter)

    render_jsonp({ files: results, success: true })
  rescue CartoDB::Datasources::TokenExpiredOrInvalidError => ex
    current_user.oauths.remove(ex.service_name)
    render_jsonp({ errors: { imports: INVALID_TOKEN_MESSAGE } }, 401)
  rescue => ex
    CartoDB::Logger.info('Error: list_files_for_service', "#{ex.message} #{ex.backtrace.inspect}")
    render_jsonp({ errors: { imports: ex.message } }, 400)
  end

  def get_service_auth_url
    oauth = current_user.oauths.select(params[:id])
    raise CartoDB::Datasources::AuthError.new("OAuth already set for service #{params[:id]}") unless oauth.nil?

    datasource = CartoDB::Datasources::DatasourcesFactory.get_datasource(
      params[:id], current_user, { redis_storage: $tables_metadata })
    raise CartoDB::Datasources::AuthError.new("Couldn't fetch datasource for service #{params[:id]}") if datasource.nil?
    unless datasource.kind_of? CartoDB::Datasources::BaseOAuth
      raise CartoDB::Datasources::InvalidServiceError.new("Datasource #{params[:id]} does not support OAuth")
    end

    render_jsonp({
                   url: datasource.get_auth_url,
                   success: true
                 })
  rescue CartoDB::Datasources::TokenExpiredOrInvalidError => ex
    current_user.oauths.remove(ex.service_name)
    render_jsonp({ errors: { imports: INVALID_TOKEN_MESSAGE } }, 401)
  rescue => ex
    CartoDB::Logger.info('Error: get_service_auth_url', "#{ex.message} #{ex.backtrace.inspect}")
    render_jsonp({ errors: { imports: ex.message } }, 400)
  end

  # Only of use if service is set to work in authorization code mode. Ignore for callback-based oauths
  def validate_service_oauth_code
    success = false

    oauth = current_user.oauths.select(params[:id])
    raise CartoDB::Datasources::AuthError.new("OAuth already set for service #{params[:id]}") unless oauth.nil?

    datasource = CartoDB::Datasources::DatasourcesFactory.get_datasource(
      params[:id], current_user, { redis_storage: $tables_metadata })
    raise CartoDB::Datasources::AuthError.new("Couldn't fetch datasource for service #{params[:id]}") if datasource.nil?
    unless datasource.kind_of? CartoDB::Datasources::BaseOAuth
      raise CartoDB::Datasources::InvalidServiceError.new("Datasource #{params[:id]} does not support OAuth")
    end

    raise "Missing oauth verification code for service #{params[:id]}" unless params[:code].present?

    begin
      auth_token = datasource.validate_auth_code(params[:code])
      current_user.oauths.add(params[:id],auth_token)
      success = true
    rescue CartoDB::Datasources::AuthError
      CartoDB::Logger.info('Error: validate_service_oauth_code', \
        "Couldn't add oauth from service #{params[:id]} for user #{current_user.username}")
    end

    render_jsonp({ success: success })
  rescue CartoDB::Datasources::TokenExpiredOrInvalidError => ex
    current_user.oauths.remove(ex.service_name)
    render_jsonp({ errors: { imports: INVALID_TOKEN_MESSAGE } }, 401)
  rescue => ex
    CartoDB::Logger.info('Error: validate_service_oauth_code', "#{ex.message} #{ex.backtrace.inspect}")
    render_jsonp({ errors: { imports: ex.message } }, 400)
  end

  def invalidate_service_token
    oauth = current_user.oauths.select(params[:id])
    raise CartoDB::Datasources::AuthError.new("No oauth set for service #{params[:id]}") if oauth.nil?

    datasource = oauth.get_service_datasource
    raise CartoDB::Datasources::AuthError.new("Couldn't fetch datasource for service #{params[:id]}") if datasource.nil?
    unless datasource.kind_of? CartoDB::Datasources::BaseOAuth
      raise CartoDB::Datasources::InvalidServiceError.new("Datasource #{params[:id]} does not support OAuth")
    end

    result = datasource.revoke_token
    if result
      current_user.oauths.remove(oauth.service)
    end

    render_jsonp({ success: true })
  rescue => ex
    CartoDB::Logger.info('Error: invalidate_service_token', "#{ex.message} #{ex.backtrace.inspect}")
    render_jsonp({ errors: { imports: ex.message } }, 400)
  end

  def service_oauth_callback
    oauth = current_user.oauths.select(params[:id])
    raise CartoDB::Datasources::AuthError.new("OAuth already set for service #{params[:id]}") unless oauth.nil?

    datasource = CartoDB::Datasources::DatasourcesFactory.get_datasource(
      params[:id], current_user, { redis_storage: $tables_metadata })
    raise CartoDB::Datasources::AuthError.new("Couldn't fetch datasource for service #{params[:id]}") if datasource.nil?
    unless datasource.kind_of? CartoDB::Datasources::BaseOAuth
      raise CartoDB::Datasources::InvalidServiceError.new("Datasource #{params[:id]} does not support OAuth")
    end

    token = datasource.validate_callback(params)

    current_user.oauths.add(params[:id], token)
    request.format = 'html'
    respond_to do |format|
      format.all  { render text: '<script>window.close();</script>', content_type: 'text/html' }
    end
  rescue CartoDB::Datasources::TokenExpiredOrInvalidError => ex
    current_user.oauths.remove(ex.service_name)
    render_jsonp({ errors: { imports: INVALID_TOKEN_MESSAGE } }, 401)
  rescue => ex
    CartoDB::Logger.info('Error: service_oauth_callback', "#{ex.message} #{ex.backtrace.inspect}")
    render_jsonp({ errors: { imports: ex.message } }, 400)
  end

end
