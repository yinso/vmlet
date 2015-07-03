// Generated by CoffeeScript 1.4.0
(function() {
  var ANF, AST, LexicalEnvironment, Transformer, errorlet, get, loglet, makeProc, register, tr, transform, transformArray, transformBinary, transformBlock, transformCatch, transformDefine, transformFinally, transformFuncall, transformIdentifier, transformIf, transformMember, transformObject, transformParam, transformScalar, transformTaskcall, transformThrow, transformTry, _transTypes, _transform;

  loglet = require('loglet');

  errorlet = require('errorlet');

  AST = require('./ast');

  LexicalEnvironment = require('./lexical');

  tr = require('./trace');

  Transformer = require('./transformer');

  ANF = require('./anf');

  _transTypes = {};

  register = function(ast, transformer) {
    if (_transTypes.hasOwnProperty(ast.type)) {
      throw errorlet.create({
        error: 'resolver_duplicate_ast_type',
        type: ast.type
      });
    } else {
      return _transTypes[ast.type] = transformer;
    }
  };

  get = function(ast) {
    if (_transTypes.hasOwnProperty(ast.constructor.type)) {
      return _transTypes[ast.constructor.type];
    } else {
      throw errorlet.create({
        error: 'resolver_unsupported_ast_type',
        type: ast.constructor.type
      });
    }
  };

  transform = function(ast, env) {
    var anf, resolved;
    resolved = _transform(ast, env);
    anf = ANF.transform(resolved, env);
    return Transformer.transform(AST["return"](anf));
  };

  _transform = function(ast, env) {
    var resolver;
    resolver = get(ast);
    return resolver(ast, env);
  };

  transformScalar = function(ast, env) {
    return ast;
  };

  register(AST.get('number'), transformScalar);

  register(AST.get('bool'), transformScalar);

  register(AST.get('null'), transformScalar);

  register(AST.get('string'), transformScalar);

  transformBinary = function(ast, env) {
    var lhs, rhs;
    lhs = _transform(ast.lhs, env);
    rhs = _transform(ast.rhs, env);
    return AST.binary(ast.op, lhs, rhs);
  };

  register(AST.get('binary'), transformBinary);

  transformIf = function(ast, env) {
    var cond, elseAST, thenAST;
    cond = _transform(ast.cond, env);
    thenAST = _transform(ast.then, env);
    elseAST = _transform(ast["else"], env);
    return AST["if"](cond, thenAST, elseAST);
  };

  register(AST.get('if'), transformIf);

  transformBlock = function(ast, env) {
    var i, items, newEnv;
    newEnv = new LexicalEnvironment(env);
    items = (function() {
      var _i, _ref, _results;
      _results = [];
      for (i = _i = 0, _ref = ast.items.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
        _results.push(_transform(ast.items[i], newEnv));
      }
      return _results;
    })();
    return AST.block(items);
  };

  register(AST.get('block'), transformBlock);

  transformDefine = function(ast, env) {
    var local, name, res;
    if (env.has(ast.name)) {
      throw new Error("duplicate_define: " + ast.name);
    }
    res = _transform(ast.value, env);
    if (env.level() === 0) {
      console.log('resolver.define', ast);
      env.define(ast.name, res);
      console.log('resolver.define.after', ast);
      return AST.define(ast.name, res);
    } else {
      name = env.defineLocal(ast.name, res);
      local = AST.local(name, res);
      tr.log('--transform.define.local', ast.name, res, name, local);
      return local;
    }
  };

  register(AST.get('define'), transformDefine);

  transformIdentifier = function(ast, env) {
    if (env.has(ast)) {
      return ast;
    } else {
      throw errorlet.create({
        error: 'RESOLVER.transform:unknown_identifier',
        id: ast
      });
    }
  };

  register(AST.get('symbol'), transformIdentifier);

  transformObject = function(ast, env) {
    var key, keyVals, v, val;
    keyVals = (function() {
      var _i, _len, _ref, _ref1, _results;
      _ref = ast.value;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _ref1 = _ref[_i], key = _ref1[0], val = _ref1[1];
        v = _transform(val, env);
        _results.push([key, v]);
      }
      return _results;
    })();
    return AST.object(keyVals);
  };

  register(AST.get('object'), transformObject);

  transformArray = function(ast, env) {
    var items, v;
    items = (function() {
      var _i, _len, _ref, _results;
      _ref = ast.value;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        v = _ref[_i];
        _results.push(_transform(v, env));
      }
      return _results;
    })();
    return AST.array(items);
  };

  register(AST.get('array'), transformArray);

  transformMember = function(ast, env) {
    var head;
    head = _transform(ast.head, env);
    return AST.member(head, ast.key);
  };

  register(AST.get('member'), transformMember);

  transformFuncall = function(ast, env) {
    var arg, args, funcall;
    args = (function() {
      var _i, _len, _ref, _results;
      _ref = ast.args;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        arg = _ref[_i];
        _results.push(_transform(arg, env));
      }
      return _results;
    })();
    funcall = _transform(ast.funcall, env);
    return AST.make('funcall', funcall, args);
  };

  register(AST.get('funcall'), transformFuncall);

  transformTaskcall = function(ast, env) {
    var arg, args, funcall;
    args = (function() {
      var _i, _len, _ref, _results;
      _ref = ast.args;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        arg = _ref[_i];
        _results.push(_transform(arg, env));
      }
      return _results;
    })();
    funcall = _transform(ast.funcall, env);
    return AST.make('taskcall', funcall, args);
  };

  register(AST.get('taskcall'), transformTaskcall);

  transformParam = function(ast, env) {
    return ast;
  };

  register(AST.get('param'), transformParam);

  makeProc = function(type) {
    return function(ast, env) {
      var body, decl, newEnv, param, params;
      newEnv = new LexicalEnvironment(env);
      if (ast.name) {
        newEnv.define(ast.name, AST.symbol(ast.name));
      }
      params = (function() {
        var _i, _len, _ref, _results;
        _ref = ast.params;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          param = _ref[_i];
          _results.push(newEnv.defineParam(param));
        }
        return _results;
      })();
      decl = AST.make(type, ast.name, params, null);
      body = _transform(ast.body, newEnv);
      decl.body = body;
      return Transformer.transform(decl);
    };
  };

  register(AST.get('procedure'), makeProc('procedure'));

  register(AST.get('task'), makeProc('task'));

  transformThrow = function(ast, env) {
    var exp;
    exp = _transform(ast.value, env);
    return AST.make('throw', exp);
  };

  register(AST.get('throw'), transformThrow);

  transformCatch = function(ast, env) {
    var body, newEnv, ref;
    newEnv = new LexicalEnvironment(env);
    ref = newEnv.defineParam(ast.param);
    body = _transform(ast.body, newEnv);
    return AST.make('catch', ast.param, body);
  };

  transformFinally = function(ast, env) {
    var body, newEnv;
    newEnv = new LexicalEnvironment(env);
    body = _transform(ast.body, newEnv);
    return AST.make('finally', body);
  };

  transformTry = function(ast, env) {
    var body, c, catches, fin, newEnv;
    newEnv = new LexicalEnvironment(env);
    body = _transform(ast.body, newEnv);
    catches = (function() {
      var _i, _len, _ref, _results;
      _ref = ast.catches;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        _results.push(transformCatch(c, env));
      }
      return _results;
    })();
    fin = ast["finally"] instanceof AST ? transformFinally(ast["finally"], env) : null;
    return AST.make('try', body, catches, fin);
  };

  register(AST.get('try'), transformTry);

  module.exports = {
    transform: transform,
    register: register,
    get: get
  };

}).call(this);