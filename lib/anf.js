// Generated by CoffeeScript 1.4.0
(function() {
  var ANF, AST, BLOCK, Environment, LexicalEnvironment, ParamList, baseEnv, errorlet, get, loglet, override, register, transform, transformArray, transformBinary, transformBlock, transformDefine, transformFuncall, transformIdentifier, transformIf, transformMember, transformObject, transformParam, transformProcedure, transformScalar, transformThrow, types, _transform,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  loglet = require('loglet');

  errorlet = require('errorlet');

  AST = require('./ast');

  baseEnv = require('./baseenv');

  Environment = require('./environment');

  ParamList = require('./parameter');

  LexicalEnvironment = (function(_super) {

    __extends(LexicalEnvironment, _super);

    LexicalEnvironment.defaultPrefix = '___';

    LexicalEnvironment.fromParams = function(params, prev) {
      var env, gensym, param, _i, _len;
      if (prev == null) {
        prev = baseEnv;
      }
      env = new this({}, prev);
      for (_i = 0, _len = params.length; _i < _len; _i++) {
        param = params[_i];
        gensym = env.gensym(param.name);
        env.defineRef(gensym);
        env.mapLocal(param.name, gensym);
      }
      return env;
    };

    function LexicalEnvironment(inner, prev) {
      if (inner == null) {
        inner = {};
      }
      if (prev == null) {
        prev = null;
      }
      LexicalEnvironment.__super__.constructor.call(this, inner, prev);
      this.genids = this.prev instanceof this.constructor ? this.prev.genids : {};
      this.localMap = {};
    }

    LexicalEnvironment.prototype.mapParam = function(param) {
      var sym;
      sym = this.defineRef(param.name);
      return AST.make('param', sym, param.type, param["default"]);
    };

    LexicalEnvironment.prototype.defineRef = function(name) {
      var sym;
      sym = this.gensym(name);
      LexicalEnvironment.__super__.defineRef.call(this, sym);
      this.mapLocal(name, sym);
      return sym;
    };

    LexicalEnvironment.prototype.has = function(key) {
      if (this.hasLocal(key)) {
        return true;
      } else {
        return LexicalEnvironment.__super__.has.call(this, key);
      }
    };

    LexicalEnvironment.prototype.get = function(key) {
      if (this.hasLocal(key)) {
        return LexicalEnvironment.__super__.get.call(this, this.localMap[key]);
      } else {
        return LexicalEnvironment.__super__.get.call(this, key);
      }
    };

    LexicalEnvironment.prototype.mapLocal = function(name, local) {
      return this.localMap[name] = local;
    };

    LexicalEnvironment.prototype.hasLocal = function(name) {
      return this.localMap.hasOwnProperty(name);
    };

    LexicalEnvironment.prototype.getLocal = function(name) {
      return this.localMap[name];
    };

    LexicalEnvironment.prototype.gensym = function(prefix) {
      if (prefix == null) {
        prefix = LexicalEnvironment.defaultPrefix;
      }
      if (!this.genids.hasOwnProperty(prefix)) {
        this.genids[prefix] = 0;
      }
      return "" + prefix + "$" + (this.genids[prefix]++);
    };

    LexicalEnvironment.prototype.assign = function(val, sym) {
      var varName;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      varName = this.gensym(sym);
      this.define(varName, val);
      return varName;
    };

    return LexicalEnvironment;

  })(Environment);

  types = {};

  BLOCK = AST.get('block');

  ANF = (function(_super) {

    __extends(ANF, _super);

    ANF.type = 'anf';

    ANF.genids = {};

    ANF.fromEnv = function(env) {
      if (env == null) {
        env = baseEnv;
      }
      return new this([], (env instanceof LexicalEnvironment ? env : new LexicalEnvironment({}, env)));
    };

    function ANF(items, env) {
      if (items == null) {
        items = [];
      }
      if (env == null) {
        env = new LexicalEnvironment({}, baseEnv);
      }
      ANF.__super__.constructor.call(this, items);
      this.env = env;
    }

    ANF.prototype.mapLocal = function(name, local) {
      return this.env.mapLocal(name, local);
    };

    ANF.prototype.hasLocal = function(name) {
      return this.env.hasLocal(name);
    };

    ANF.prototype.getLocal = function(name) {
      var local;
      local = this.env.getLocal(name);
      return this.env.get(local);
    };

    ANF.prototype.gensym = function(prefix) {
      if (prefix == null) {
        prefix = LexicalEnvironment.defaultPrefix;
      }
      if (!this.constructor.genids.hasOwnProperty(prefix)) {
        this.constructor.genids[prefix] = 0;
      }
      return "_" + prefix + "$" + (this.constructor.genids[prefix]++);
    };

    ANF.prototype.assign = function(val, sym) {
      var varName;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      varName = this.env.assign(val, sym);
      this.items.push(AST.make('define', varName, val));
      return AST.make('symbol', varName);
    };

    ANF.prototype.scalar = function(ast) {
      this.items.push(ast);
      return ast;
    };

    ANF.prototype.define = function(name, val) {
      return this.assign(AST.make('define', name, val));
    };

    ANF.prototype.binary = function(op, lhs, rhs, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('binary', op, lhs, rhs);
      return this.assign(ast, sym);
    };

    ANF.prototype["if"] = function(cond, thenE, elseE, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('if', cond, thenE, elseE);
      return this.assign(ast, sym);
    };

    ANF.prototype.object = function(keyVals, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('object', keyVals);
      return this.assign(ast, sym);
    };

    ANF.prototype.array = function(items, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('array', items);
      return this.assign(ast, sym);
    };

    ANF.prototype.member = function(head, key, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('member', head, key);
      return this.assign(ast, sym);
    };

    ANF.prototype.funcall = function(funcall, args, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('funcall', funcall, args);
      return this.assign(ast, sym);
    };

    ANF.prototype.procedure = function(name, params, body, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('procedure', name, params, body);
      return this.assign(ast, sym);
    };

    ANF.prototype["throw"] = function(exp, sym) {
      var ast;
      if (sym == null) {
        sym = LexicalEnvironment.defaultPrefix;
      }
      ast = AST.make('throw', exp);
      return this.assign(ast, sym);
    };

    ANF.prototype.normalize = function() {
      loglet.log('ANF.normalize', this);
      this.stripScalars();
      return this.propagateReturn();
    };

    ANF.prototype.stripScalars = function() {
      var i, item, items, _i, _len, _ref;
      items = [];
      _ref = this.items;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        item = _ref[i];
        if (i < this.items.length - 1) {
          if (item.type() === 'define') {
            items.push(this.normalizeDefine(item));
          } else if (item.type() === 'throw') {
            items.push(item);
          }
        } else {
          items.push(item);
        }
      }
      return this.items = items;
    };

    ANF.prototype.normalizeDefine = function(ast) {
      var name, valAST;
      name = ast.name;
      valAST = ast.val;
      switch (valAST.type()) {
        case 'number':
        case 'string':
        case 'bool':
        case 'null':
        case 'symbol':
        case 'binary':
        case 'funcall':
        case 'member':
        case 'procedure':
        case 'array':
        case 'object':
        case 'ref':
          return ast;
        default:
          return this._normalizeDefine(name, valAST);
      }
    };

    ANF.prototype._normalizeDefine = function(name, ast) {
      var elseE, i, item, items, thenE;
      loglet.log('_normalizeDefine', name, ast);
      switch (ast.type()) {
        case 'if':
          thenE = this._normalizeDefine(name, ast.then);
          elseE = this._normalizeDefine(name, ast["else"]);
          return AST.make('if', ast["if"], thenE, elseE);
        case 'block':
          items = (function() {
            var _i, _len, _ref, _results;
            _ref = ast.items;
            _results = [];
            for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
              item = _ref[i];
              if (i < ast.items.length - 1) {
                _results.push(item);
              } else {
                _results.push(this._normalizeDefine(name, item));
              }
            }
            return _results;
          }).call(this);
          return AST.make('block', items);
        case 'anf':
          items = (function() {
            var _i, _len, _ref, _results;
            _ref = ast.items;
            _results = [];
            for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
              item = _ref[i];
              if (i < ast.items.length - 1) {
                _results.push(item);
              } else {
                _results.push(this._normalizeDefine(name, item));
              }
            }
            return _results;
          }).call(this);
          return new ANF(items, this.env);
        default:
          throw errorlet.create({
            error: 'ANF._normalizeReturn:unsupported_ast_type',
            type: ast.type()
          });
      }
    };

    ANF.prototype.propagateReturn = function() {
      var ast;
      ast = this.items.pop();
      return this.items.push(this._propagateReturn(ast));
    };

    ANF.prototype._propagateReturn = function(ast) {
      var elseE, i, item, items, thenE;
      switch (ast.type()) {
        case 'define':
          return this._propagateReturn(ast.val);
        case 'number':
        case 'string':
        case 'bool':
        case 'null':
        case 'symbol':
        case 'binary':
        case 'funcall':
        case 'member':
        case 'procedure':
        case 'array':
        case 'object':
        case 'ref':
          return AST.make('return', ast);
        case 'if':
          thenE = this._propagateReturn(ast.then);
          elseE = this._propagateReturn(ast["else"]);
          return AST.make('if', ast["if"], thenE, elseE);
        case 'block':
          items = (function() {
            var _i, _len, _ref, _results;
            _ref = ast.items;
            _results = [];
            for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
              item = _ref[i];
              if (i < ast.items.length - 1) {
                _results.push(item);
              } else {
                _results.push(this._propagateReturn(item));
              }
            }
            return _results;
          }).call(this);
          return AST.make('block', items);
        case 'anf':
          items = (function() {
            var _i, _len, _ref, _results;
            _ref = ast.items;
            _results = [];
            for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
              item = _ref[i];
              if (i < ast.items.length - 1) {
                _results.push(item);
              } else {
                _results.push(this._propagateReturn(item));
              }
            }
            return _results;
          }).call(this);
          return new ANF(items, this.env);
        case 'return':
          return ast;
        case 'throw':
          return ast;
        default:
          throw errorlet.create({
            error: 'ANF.propagateReturn:unsupported_ast_type',
            type: ast.type()
          });
      }
    };

    ANF.prototype.toString = function() {
      var buffer, stmt, _i, _len, _ref;
      buffer = [];
      buffer.push('{ANF');
      _ref = this.items;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        stmt = _ref[_i];
        buffer.push("  " + stmt);
      }
      buffer.push('}');
      return buffer.join('\n');
    };

    return ANF;

  })(BLOCK);

  register = function(ast, transformer) {
    if (types.hasOwnProperty(ast.type)) {
      throw errorlet.create({
        error: 'anf_duplicate_ast_type',
        type: ast.type
      });
    } else {
      return types[ast.type] = transformer;
    }
  };

  get = function(ast) {
    if (types.hasOwnProperty(ast.constructor.type)) {
      return types[ast.constructor.type];
    } else {
      throw errorlet.create({
        error: 'anf_unsupported_ast_type',
        type: ast.constructor.type
      });
    }
  };

  override = function(ast, transformer) {
    return types[ast.type] = transformer;
  };

  transform = function(ast, env, anf, level) {
    if (env == null) {
      env = baseEnv;
    }
    if (anf == null) {
      anf = ANF.fromEnv(env);
    }
    if (level == null) {
      level = 0;
    }
    loglet.log('--TRANSFORM', ast, anf, level);
    _transform(ast, anf, level);
    anf.normalize();
    return anf;
  };

  _transform = function(ast, anf, level) {
    var transformer, type;
    if (anf == null) {
      anf = ANF.fromEnv(baseEnv);
    }
    if (level == null) {
      level = 0;
    }
    loglet.log('--transform', ast, anf, level);
    type = ast.constructor.type;
    if (types.hasOwnProperty(type)) {
      transformer = get(ast);
      return transformer(ast, anf, level);
    } else {
      throw errorlet.create({
        error: 'anf_unsupported_ast_type',
        type: type
      });
    }
  };

  transformScalar = function(ast, anf, level) {
    return anf.scalar(ast);
  };

  register(AST.get('number'), transformScalar);

  register(AST.get('bool'), transformScalar);

  register(AST.get('null'), transformScalar);

  register(AST.get('string'), transformScalar);

  transformBinary = function(ast, anf, level) {
    var lhs, rhs;
    lhs = _transform(ast.lhs, anf, level);
    rhs = _transform(ast.rhs, anf, level);
    return anf.binary(ast.op, lhs, rhs);
  };

  register(AST.get('binary'), transformBinary);

  transformIf = function(ast, anf, level) {
    var cond, elseAST, thenAST;
    loglet.log('--transformIf', ast, anf, level);
    cond = _transform(ast["if"], anf, level);
    thenAST = transform(ast.then, anf.env, ANF.fromEnv(anf.env), level);
    elseAST = transform(ast["else"], anf.env, ANF.fromEnv(anf.env), level);
    return anf["if"](cond, thenAST, elseAST);
  };

  register(AST.get('if'), transformIf);

  transformBlock = function(ast, anf, level) {
    var i, _i, _ref;
    for (i = _i = 0, _ref = ast.items.length - 1; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      _transform(ast.items[i], anf, level);
    }
    return _transform(ast.items[ast.items.length - 1], anf, level);
  };

  register(AST.get('block'), transformBlock);

  transformDefine = function(ast, anf, level) {
    var res;
    loglet.log('transformDefine', ast);
    res = _transform(ast.val, anf, level);
    return anf.define(ast.name, res);
  };

  register(AST.get('define'), transformDefine);

  transformObject = function(ast, anf, level) {
    var key, keyVals, v, val;
    keyVals = (function() {
      var _i, _len, _ref, _ref1, _results;
      _ref = ast.val;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _ref1 = _ref[_i], key = _ref1[0], val = _ref1[1];
        v = _transform(val, anf, level);
        _results.push([key, v]);
      }
      return _results;
    })();
    return anf.object(keyVals);
  };

  register(AST.get('object'), transformObject);

  transformArray = function(ast, anf, level) {
    var items, v;
    items = (function() {
      var _i, _len, _ref, _results;
      _ref = ast.val;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        v = _ref[_i];
        _results.push(_transform(v, anf, level));
      }
      return _results;
    })();
    return anf.array(items);
  };

  register(AST.get('array'), transformArray);

  transformMember = function(ast, anf, level) {
    var head;
    head = _transform(ast.head, anf, level);
    return anf.member(head, ast.key);
  };

  register(AST.get('member'), transformMember);

  transformIdentifier = function(ast, anf, level) {
    loglet.log('--transformIdentifier', ast, anf, level);
    if (anf.env.has(ast.val)) {
      return anf.scalar(anf.env.get(ast.val));
    } else if (anf.hasLocal(ast.val)) {
      return anf.getLocal(ast.val);
    } else {
      throw errorlet.create({
        error: 'ANF.transform:unknown_identifier',
        id: ast.val
      });
    }
  };

  register(AST.get('symbol'), transformIdentifier);

  transformFuncall = function(ast, anf, level) {
    var arg, args, funcall;
    loglet.log('--transformFuncall', ast, anf, level);
    args = (function() {
      var _i, _len, _ref, _results;
      _ref = ast.args;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        arg = _ref[_i];
        _results.push(_transform(arg, anf, level));
      }
      return _results;
    })();
    funcall = _transform(ast.funcall, anf, level);
    return anf.funcall(funcall, args);
  };

  register(AST.get('funcall'), transformFuncall);

  transformParam = function(ast, anf, level) {
    return ast;
  };

  register(AST.get('param'), transformParam);

  transformProcedure = function(ast, anf, level) {
    var body, name, newEnv, param, params;
    newEnv = new LexicalEnvironment({}, anf.env);
    name = ast.name ? newEnv.defineRef(ast.name) : void 0;
    params = (function() {
      var _i, _len, _ref, _results;
      _ref = ast.params;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        param = _ref[_i];
        _results.push(newEnv.mapParam(param));
      }
      return _results;
    })();
    body = transform(ast.body, newEnv, ANF.fromEnv(newEnv), level + 1);
    return anf.procedure(name, params, body);
    /*
      newEnv = LexicalEnvironment.fromParams ast.params, anf.env
      if ast.name
        newEnv.defineRef ast.name
      body = transform ast.body, newEnv
      params = 
        for param in ast.params
          local = newEnv.getLocal param.name
          AST.make 'param', local
      anf.procedure ast.name, params, body
    */

  };

  register(AST.get('procedure'), transformProcedure);

  transformThrow = function(ast, anf, level) {
    var exp;
    exp = _transform(ast.val, anf, level);
    return anf["throw"](exp);
  };

  register(AST.get('throw'), transformThrow);

  module.exports = {
    register: register,
    isANF: function(v) {
      return v instanceof ANF;
    },
    ANF: ANF,
    get: get,
    override: override,
    transform: transform
  };

}).call(this);