// Generated by CoffeeScript 1.4.0
(function() {
  var isAsync, isFunction, isSync;

  isFunction = function(func) {
    return typeof func === 'function' || func instanceof Function;
  };

  isAsync = function(func) {
    var _ref;
    return isFunction(func) && ((_ref = func.__vmlet) != null ? _ref.async : void 0);
  };

  isSync = function(func) {
    return isFunction(func) && !func.__vmlet.async;
  };

  module.exports = {
    isFunction: isFunction,
    isAsync: isAsync,
    isSync: isSync
  };

}).call(this);