var cdb = require('cartodb.js');

var BaseDialog = cdb.ui.common.Dialog;

/**
 * Abstract view for a dialog, a kind of view that takes up the full screen overlaying any previous content.
 *
 * To be extended for a specific use-case.
 * It inherits from CartoDB.js' Dialog view so has some particular behavior/convention of how to be used, see example
 *
 * Example of how to use:
 *   // Extend this view
 *   var MyDialog = BaseDialog.extend({
 *     render_content: function() {
 *       return 'Hello world!';
 *     }
 *   });
 *
 *   // Create instance object.
 *   var dialog = new MyDialog();
 *
 *   // To render & show initially (only to be called once):
 *   dialog.appendToBody();
 */
module.exports = BaseDialog.extend({
  className: 'Dialog is-opening',

  overrideDefaults: {
    template_name: 'new_common/views/base_dialog/template'
  },

  initialize: function() {
    // Override defaults of parent
    _.defaults(this.options, this.overrideDefaults);
    this.elder('initialize');
    this.bind('show', this._setBodyForDialogMode.bind(this, 'add'));
    this.bind('hide', this._setBodyForDialogMode.bind(this, 'remove'));
  },

  show: function() {
    BaseDialog.prototype.show.apply(this, arguments);
    this.trigger('show');
  },

  hide: function() {
    BaseDialog.prototype.hide.apply(this, arguments);
    this.trigger('hide');
  },
  
  render: function() {
    BaseDialog.prototype.render.apply(this, arguments);
    this.show();
    return this;
  },

  /**
   * Like calling render but do a similar is-opening animation for the (new) content.
   */
  reRenderAnimated: function() {
    this.render();
    this.$('.content')
      .addClass('is-newContent');
  },
  
  replaceContent: function(newContent) {
    this.$el.html(this.template_base());
    this.$('.content')
      .html(newContent)
      .addClass('is-newContent');
  },
  
  close: function() {
    this._close(null, '_cancel');
  },

  _close: function(ev, finishFnName) {
    if (ev) this.killEvent(ev);
    this.$el.addClass('is-closing');

    // Use timeout instead of event listener on animation since the event triggered differs depending on browser
    // Timing won't perhaps be 100% accurate but it's good enough
    // The timeout should match the .Dialog.is-closing animation duration.
    var self = this;
    setTimeout(function() {
      self.hide();
      BaseDialog.prototype[finishFnName].call(self);
    }, 80); //ms
  },

  _setBodyForDialogMode: function(action) {
    $('body')[action +'Class']('is-inDialog');
  },

  _ok: function(ev) {
    this._close(ev, '_ok');
  },

  /**
   * @override cdb.ui.common.Dialog.prototype._cancel to implement animation upon closing the dialog
   */
  _cancel: function(ev) {
    this._close(ev, '_cancel');
  }

});
