// Generated by CoffeeScript 1.4.0
(function() {
  var indent, isTracedHead, isTracedTail, log, objToStr, printObj, tab, tempName, trace, untab, untrace, _level, _temp, _trace, _traced, _untrace,
    __slice = [].slice;

  _level = 0;

  indent = function(count) {
    var i;
    return ((function() {
      var _i, _results;
      _results = [];
      for (i = _i = 0; 0 <= _level ? _i < _level : _i > _level; i = 0 <= _level ? ++_i : --_i) {
        _results.push('  ');
      }
      return _results;
    })()).join('') + ((function() {
      var _i, _results;
      _results = [];
      for (i = _i = 0; 0 <= count ? _i < count : _i > count; i = 0 <= count ? ++_i : --_i) {
        _results.push(' ');
      }
      return _results;
    })()).join('');
  };

  tab = function(name, show) {
    var after, i;
    if (show == null) {
      show = true;
    }
    after = show ? "--> " + name : ((function() {
      var _i, _results;
      _results = [];
      for (i = _i = 0; _i < 7; i = ++_i) {
        _results.push(' ');
      }
      return _results;
    })()).join('');
    return ((function() {
      var _i, _results;
      _results = [];
      for (i = _i = 0; 0 <= _level ? _i < _level : _i > _level; i = 0 <= _level ? ++_i : --_i) {
        _results.push('  ');
      }
      return _results;
    })()).join('') + after;
  };

  untab = function(name, show) {
    var after, i;
    if (show == null) {
      show = true;
    }
    after = show ? "<-- " + name : ((function() {
      var _i, _results;
      _results = [];
      for (i = _i = 0; _i < 7; i = ++_i) {
        _results.push(' ');
      }
      return _results;
    })()).join('');
    return ((function() {
      var _i, _results;
      _results = [];
      for (i = _i = 0; 0 <= _level ? _i < _level : _i > _level; i = 0 <= _level ? ++_i : --_i) {
        _results.push('  ');
      }
      return _results;
    })()).join('') + after;
  };

  _traced = [];

  isTracedHead = function(proc) {
    var i, orig, traced, _i, _len, _ref;
    for (i = _i = 0, _len = _traced.length; _i < _len; i = ++_i) {
      _ref = _traced[i], orig = _ref[0], traced = _ref[1];
      if (orig === proc) {
        return i;
      }
    }
    return -1;
  };

  isTracedTail = function(proc) {
    var i, orig, traced, _i, _len, _ref;
    for (i = _i = 0, _len = _traced.length; _i < _len; i = ++_i) {
      _ref = _traced[i], orig = _ref[0], traced = _ref[1];
      if (traced === proc) {
        return true;
      }
    }
    return -1;
  };

  _temp = 0;

  tempName = function() {
    return "__$" + (_temp++);
  };

  objToStr = function(arg) {
    var i, str, _i, _len, _ref, _results;
    if (arg === null) {
      return [indent(2) + 'null'];
    }
    if (arg === void 0) {
      return [indent(2) + 'undefined'];
    }
    _ref = JSON.stringify(arg, null, 2).split('\n');
    _results = [];
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      str = _ref[i];
      if (i === 0) {
        _results.push(indent(2) + str);
      } else {
        _results.push(indent(4) + str);
      }
    }
    return _results;
  };

  printObj = function(arg) {
    var str, strs, _i, _len, _results;
    strs = objToStr(arg);
    _results = [];
    for (_i = 0, _len = strs.length; _i < _len; _i++) {
      str = strs[_i];
      _results.push(console.log(str));
    }
    return _results;
  };

  _trace = function(name, args) {
    var arg, _i, _len, _results;
    console.log(tab(name));
    _results = [];
    for (_i = 0, _len = args.length; _i < _len; _i++) {
      arg = args[_i];
      _results.push(printObj(arg));
    }
    return _results;
  };

  _untrace = function(name, arg) {
    console.log(untab(name));
    return printObj(arg);
  };

  trace = function(name, proc) {
    var res, traced, _ref;
    if (arguments.length === 1) {
      proc = name;
      name = ((_ref = proc.name) != null ? _ref.length : void 0) > 0 ? proc.name : tempName();
    }
    res = isTracedHead(proc);
    if (res > -1) {
      return _traced[res][1];
    }
    traced = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      _trace(name, args);
      _level++;
      try {
        res = proc.apply(this, args);
      } finally {
        _level--;
      }
      _untrace(name, res);
      return res;
    };
    _traced.push([proc, traced]);
    return traced;
  };

  untrace = function(traced) {
    var orig, res;
    res = isTracedTail(traced);
    if (res > -1) {
      orig = _traced[res][0];
      _traced.splice(i, 1);
      return orig;
    } else {
      return traced;
    }
  };

  log = function() {
    var arg, args, _i, _len, _results;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    _results = [];
    for (_i = 0, _len = args.length; _i < _len; _i++) {
      arg = args[_i];
      _results.push(printObj(arg));
    }
    return _results;
  };

  module.exports = {
    trace: trace,
    untrace: untrace,
    log: log
  };

}).call(this);