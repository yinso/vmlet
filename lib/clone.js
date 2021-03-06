// Generated by CoffeeScript 1.4.0
(function() {
  var AST, CloneTransformer, Environment;

  AST = require('./ast');

  Environment = require('./symboltable');

  CloneTransformer = (function() {

    CloneTransformer.transform = function(ast) {
      if (!this.reg) {
        this.reg = new this();
      }
      return this.reg.transform(ast);
    };

    function CloneTransformer() {}

    CloneTransformer.prototype.transform = function(ast) {
      return this.run(ast, Environment.make({
        newSym: true
      }));
    };

    CloneTransformer.prototype.run = function(ast, env) {
      var type;
      type = "_" + (ast.type());
      if (this[type]) {
        return this[type](ast, env);
      } else {
        throw new Error("clone:unknown_type: " + (ast.type()));
      }
    };

    CloneTransformer.prototype._number = function(ast, env) {
      return ast;
    };

    CloneTransformer.prototype._string = function(ast, env) {
      return ast;
    };

    CloneTransformer.prototype._bool = function(ast, env) {
      return ast;
    };

    CloneTransformer.prototype._null = function(ast, env) {
      return ast;
    };

    CloneTransformer.prototype._unit = function(ast, env) {
      return ast;
    };

    CloneTransformer.prototype._symbol = function(ast, env) {
      var ref;
      ref = env.alias(ast);
      return ref.name;
    };

    CloneTransformer.prototype._ref = function(ast, env) {
      return env.alias(ast.name);
    };

    CloneTransformer.prototype._define = function(ast, env) {
      var cloned, ref;
      ref = this.run(ast.name, env);
      cloned = this.run(ast.value, env);
      ref.value = cloned;
      return AST.define(ref, cloned);
    };

    CloneTransformer.prototype._local = function(ast, env) {
      var cloned, ref;
      ref = this.run(ast.name, env);
      cloned = this.run(ast.value, env);
      ref.value = cloned;
      return AST.local(ref, cloned);
    };

    CloneTransformer.prototype._assign = function(ast, env) {
      var cloned, ref;
      ref = this.run(ast.name, env);
      cloned = this.run(ast.value, env);
      ref.value = cloned;
      return AST.local(ref, cloned);
    };

    CloneTransformer.prototype._if = function(ast, env) {
      var cond, elseAST, thenAST;
      cond = this.run(ast.cond, env);
      thenAST = this.run(ast.then, env);
      elseAST = this.run(ast["else"], env);
      return AST["if"](cond, thenAST, elseAST);
    };

    CloneTransformer.prototype._binary = function(ast, env) {
      var lhs, rhs;
      lhs = this.run(ast.lhs, env);
      rhs = this.run(ast.rhs, env);
      return AST.binary(ast.op, lhs, rhs);
    };

    CloneTransformer.prototype._member = function(ast, env) {
      var head, key;
      head = this.run(ast.head, env);
      key = this.run(ast.key, env);
      return AST.member(head, key);
    };

    CloneTransformer.prototype._array = function(ast, env) {
      var item, items;
      items = (function() {
        var _i, _len, _ref, _results;
        _ref = ast.value;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(this.run(item, env));
        }
        return _results;
      }).call(this);
      return AST.array(items);
    };

    CloneTransformer.prototype._object = function(ast, env) {
      var key, keyvals, val;
      keyvals = (function() {
        var _i, _len, _ref, _ref1, _results;
        _ref = ast.value;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          _ref1 = _ref[_i], key = _ref1[0], val = _ref1[1];
          _results.push([key, this.run(val, env)]);
        }
        return _results;
      }).call(this);
      return AST.object(keyvals);
    };

    CloneTransformer.prototype._block = function(ast, env) {
      var item;
      return AST.block((function() {
        var _i, _len, _ref, _results;
        _ref = ast.items;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(this.run(item, env));
        }
        return _results;
      }).call(this));
    };

    CloneTransformer.prototype._funcall = function(ast, env) {
      var arg, args, funcall;
      funcall = this.run(ast.funcall, env);
      args = (function() {
        var _i, _len, _ref, _results;
        _ref = ast.args;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          arg = _ref[_i];
          _results.push(this.run(arg, env));
        }
        return _results;
      }).call(this);
      return AST.funcall(funcall, args);
    };

    CloneTransformer.prototype._taskcall = function(ast, env) {
      var arg, args, taskcall;
      taskcall = this.run(ast.funcall, env);
      args = (function() {
        var _i, _len, _ref, _results;
        _ref = ast.args;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          arg = _ref[_i];
          _results.push(this.run(arg, env));
        }
        return _results;
      }).call(this);
      return AST.taskcall(taskcall, args);
    };

    CloneTransformer.prototype._param = function(ast, env) {
      var name, param;
      name = this.run(ast.name, env);
      param = AST.param(name, ast.paramType, ast["default"]);
      return param;
    };

    CloneTransformer.prototype._procedure = function(ast, env) {
      var decl, free, name, param, params;
      name = ast.name ? this.run(ast.name, env) : ast.name;
      params = (function() {
        var _i, _len, _ref, _results;
        _ref = ast.params;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          param = _ref[_i];
          _results.push(this.run(param, env));
        }
        return _results;
      }).call(this);
      decl = AST.procedure(name, params);
      decl.body = this.run(ast.body, env);
      decl.frees = (function() {
        var _i, _len, _ref, _results;
        _ref = ast.frees || [];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          free = _ref[_i];
          _results.push(this.run(free, env));
        }
        return _results;
      }).call(this);
      name.value = decl;
      return decl;
    };

    CloneTransformer.prototype._task = function(ast, env) {
      var decl, name, param, params;
      name = ast.name ? this.run(ast.name, env) : ast.name;
      params = (function() {
        var _i, _len, _ref, _results;
        _ref = ast.params;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          param = _ref[_i];
          _results.push(this.run(param, env));
        }
        return _results;
      }).call(this);
      decl = AST.task(name, params);
      decl.body = this.run(ast.body, env);
      name.value = decl;
      return decl;
    };

    CloneTransformer.prototype._return = function(ast, env) {
      return AST["return"](this.run(ast.value, env));
    };

    return CloneTransformer;

  })();

  module.exports = CloneTransformer;

}).call(this);
