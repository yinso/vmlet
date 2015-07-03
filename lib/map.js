// Generated by CoffeeScript 1.4.0
(function() {
  var HashMap, isFunc;

  isFunc = function(v) {
    return typeof f === 'function' || v instanceof Function;
  };

  HashMap = (function() {

    function HashMap() {
      Object.defineProperty(this, 'buckets', {
        readonly: true,
        value: []
      });
    }

    HashMap.prototype.getHashCode = function(key) {
      if (key === void 0) {
        throw new Error("HashMap.invalid_key:undefined");
      }
      if (key === null) {
        throw new Error("HashMap.invalid_key:null");
      }
      if (isFunc(key.hashCode)) {
        return key.hashCode();
      } else {
        throw new Error("HashMap.unsupported_key_type_must_implement_hashCode");
      }
    };

    HashMap.prototype.set = function(key, val) {
      var hashCode, kv, _i, _len, _ref;
      hashCode = this.getHashCode(key);
      this.buckets[hashCode] = this.buckets[hashCode] || [];
      _ref = this.buckets[hashCode];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        kv = _ref[_i];
        if (kv.key.equals(key)) {
          kv.val = val;
          return this;
        }
      }
      this.buckets[hashCode].push({
        key: key,
        val: val
      });
      return this;
    };

    HashMap.prototype._get = function(key) {
      var hashCode, kv, _i, _len, _ref;
      hashCode = this.getHashCode(key);
      _ref = this.buckets[hashCode] || [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        kv = _ref[_i];
        if (kv.key.equals(key)) {
          return kv;
        }
      }
      return void 0;
    };

    HashMap.prototype.get = function(key) {
      var res;
      res = this._get(key);
      if (res) {
        return res.val;
      } else {
        return res;
      }
    };

    HashMap.prototype.has = function(key) {
      var res;
      res = this._get(key);
      return res instanceof Object;
    };

    HashMap.prototype["delete"] = function(key) {
      var count, hashCode, i, kv, _i, _len, _ref;
      hashCode = this.getHashCode(key);
      if (!this.buckets.hasOwnProperty(hashCode)) {
        return false;
      }
      count = -1;
      _ref = this.buckets[hashCode];
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        kv = _ref[i];
        if (kv.key.equals(key)) {
          count = i;
        }
      }
      if (count !== -1) {
        this.buckets[hashCode].splice(count, 1);
        return true;
      } else {
        return false;
      }
    };

    return HashMap;

  })();

  module.exports = HashMap;

}).call(this);