var $ = require('jquery');
var cdb = require('cartodb.js');
var UploadConfig = require('new_common/upload_config');
var ErrorDetailsDialog = require('new_dashboard/dialogs/error_details_view');
var SuccessDetailsDialog = require('new_dashboard/dialogs/success_details_view');

/** 
 *  Import item within background importer
 *
 */

module.exports = cdb.core.View.extend({

  className: 'ImportItem',
  tagName: 'li',

  events: {
    'click .js-abort':      '_abortUpload',
    'click .js-show_error': '_showImportError',
    'click .js-show_stats': '_showImportStats',
    'click .js-close':      '_removeItem'
  },

  initialize: function() {
    this.router = this.options.router;
    this.template = cdb.templates.getTemplate('new_dashboard/views/background_importer/background_importer_item_view');
    this._initBinds();
  },

  render: function() {
    var upload = this.model.get('upload');
    var imp = this.model.get('import');

    var d = {
      name: '',
      state: this.model.get('state'),
      progress: '',
      service: '',
      url: '',
      failed: this.model.hasFailed(),
      completed: this.model.hasCompleted(),
      tables_created_count: imp.tables_created_count
    };
    
    // URL
    if (imp.table_name) {
      var table = new cdb.admin.CartoDBTableMetadata({ name: imp.table_name });
      d.url = encodeURI(this.router.currentUserUrl.datasetsUrl().toDataset(table))
    }

    // Name
    if (upload.type) {
      if (upload.type === "file") {
        if (upload.value.length > 1) {
          d.name = upload.value.length + ' files'
        } else {
          d.name = upload.value[0].name  
        }
      }
      if (upload.type === "url") { d.name = upload.value }
      if (upload.type === "service") { d.name = upload.service_name }  
    } else {
      d.name = imp.item_queue_id || 'import';
    }

    // Service
    if (this.model.get('upload').service_name) {
      d.service = this.model.get('upload').service_name;
    }

    // Progress
    if (this.model.get('step') === 'upload') {
      d.progress = this.model.get('upload').progress;
    } else {
      d.progress = (UploadConfig.uploadStates.indexOf(d.state)/UploadConfig.uploadStates.length) * 100;
    }

    this.$el.html(this.template(d));

    return this;
  },

  _initBinds: function() {
    this.model.bind('change:state', this._onStateChange, this);
    this.model.bind('change', this.render, this);
    this.model.bind('remove', this.clean, this);
  },

  _onStateChange: function() {
    if (this.model.get('state') === "complete") {
      this.trigger('completed', this);  
    }
  },

  _removeItem: function() {
    this.trigger('remove', this.model, this);
    this.model.pause();
    this.clean();
  },

  _showImportStats: function() {
    var self = this;
    this.trigger('dialogOpened', this);

    (new SuccessDetailsDialog({
      model: this.model
    })).bind('hide', function(){
      this.clean();
      self.trigger('dialogClosed', self);
    }).appendToBody();
  },

  _abortUpload: function() {
    this.model.stopUpload();
  },

  _showImportError: function() {
    var self = this;
    this.trigger('dialogOpened', this);

    (new ErrorDetailsDialog({
      model: this.model
    })).bind('hide', function(){
      this.clean();
      self.trigger('dialogClosed', self);
    }).appendToBody();
  }

})