var Backbone = require('backbone');
var _ = require('underscore');
var OptionModel = require('./option_model');
var PasswordOptionModel = require('./password_option_model');

/**
 * type property should match the value given from the API.
 */
var ALL_OPTIONS = [{
  privacy: 'PUBLIC',
  illustrationType: 'positive',
  iconFontType: 'Unlock',
  title: 'Public',
  desc: 'Everyone can view your table and download it',
  alwaysEnable: true
},{
  privacy: 'LINK',
  illustrationType: 'alert',
  iconFontType: 'Unlock',
  title: 'With link',
  desc: 'Only people with a share link can view the data'
},{
  privacy: 'PASSWORD',
  illustrationType: 'alert',
  iconFontType: 'Unlock--withEllipsis',
  title: 'Password protected',
  desc: 'Set a password and share only with specific people',
},{
  privacy: 'PRIVATE',
  illustrationType: 'negative',
  iconFontType: 'Lock',
  title: 'Private',
  desc: 'Nobody can access this dataset'
}];


/**
 * Collection that holds the different privacy options.
 */
module.exports = Backbone.Collection.extend({
  
  model: function(attrs, options) {
    if (attrs.privacy === 'PASSWORD') {
      return new PasswordOptionModel(attrs, options);
    } else {
      return new OptionModel(attrs, options);
    }
  },
  
  initialize: function() {
    this.bind('change', this._deselectLastSelected, this)
  },
  
  selectedOption: function() {
    return this.find(function(option) {
      return option.get('selected');
    })
  },

  passwordOption: function() {
    return this.find(function(option) {
      return option.get('privacy') === 'PASSWORD';
    })
  },

  _deselectLastSelected: function(newSelectedOption, what) {
    if (what.changes.selected) {
      this.each(function(option) {
        if (option !== newSelectedOption) {
          option.set({selected: false}, {silent: true});
        }
      });
    }
  }

}, { // Class properties:
  
  /**
   * Get a privacy options collection from a Vis model
   *
   * Note that since the user's permissions should change very seldom, it's reasonable to assume they will be static for 
   * the collection's lifecycle, so set them on the models attrs when creating the collection.
   * collection is created.
   *  
   * @param vis {Object} instance of cdb.admin.Visualization
   * @param user {Object} instance of cdb.admin.User
   * @returns {Object} instance of this collection
   */
  byVisAndUser: function(vis, user) {
    var canSelectPremiumOptions = user.get('actions')[ vis.isVisualization() ? 'private_maps' : 'private_tables' ];
    var currentPrivacy = vis.get('privacy');
    var availableOptions = vis.privacyOptions();

    return new this(
      _.chain(ALL_OPTIONS)
        .filter(function(option) {
          return _.contains(availableOptions, option.privacy);
        })
        .map(function(option) {
          // Set state that depends on vis and user attrs, they should not vary during the lifecycle of this collection
          return _.defaults({
            selected: option.privacy === currentPrivacy,
            disabled: !(option.alwaysEnable || canSelectPremiumOptions)
          }, option)
        })
        .value()
    );
  }
});


