// Generated by CoffeeScript 1.4.0
(function() {
  var Deferred, Promise, loglet,
    __slice = [].slice;

  Promise = require('lie');

  loglet = require('loglet');

  Promise.nodeify = function(proc) {
    var result;
    result = function() {
      var args, cb, isCBFunction, promise, _i;
      args = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), cb = arguments[_i++];
      isCBFunction = typeof cb === 'function' || cb instanceof Function;
      if (!isCBFunction) {
        args.push(cb);
      }
      promise = new Promise(function(resolve, reject) {
        return proc.apply(null, __slice.call(args).concat([function(err, data) {
          if (err) {
            return reject(err);
          } else {
            return resolve(data);
          }
        }]));
      });
      if (isCBFunction) {
        return promise.then(function(res) {
          return cb(null, res);
        })["catch"](function(err) {
          return cb(err);
        });
      } else {
        return promise;
      }
    };
    result.__vmlet = {
      async: true
    };
    return result;
  };

  Promise.Deferred = Deferred = (function() {

    function Deferred(promise, resolve, reject) {
      this.promise = promise;
      this.resolve = resolve;
      this.reject = reject;
    }

    return Deferred;

  })();

  Promise.defer = function() {
    var p, reject, resolve;
    resolve = null;
    reject = null;
    p = new Promise(function() {
      resolve = arguments[0];
      return reject = arguments[1];
    });
    return new Deferred(p, resolve, reject);
  };

  module.exports = Promise;

}).call(this);