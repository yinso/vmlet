// Generated by CoffeeScript 1.4.0
(function() {
  var Environment, Procedure, Task, VM, baseEnv, compiler, loglet, parser;

  Task = require('./task');

  baseEnv = require('./baseenv');

  Environment = require('./environment');

  compiler = require('./compiler');

  parser = require('./parser');

  loglet = require('loglet');

  Procedure = require('./procedure');

  VM = (function() {

    VM.Procedure = Procedure;

    VM.compiler = compiler;

    VM.parser = parser;

    VM.Task = Task;

    function VM(options) {
      this.options = options != null ? options : {};
      this.baseEnv = this.options.baseEnv || baseEnv;
      this.parser = this.options.parser || parser;
      this.compiler = this.options.compiler || compiler;
    }

    VM.prototype["eval"] = function(stmt, cb) {
      var ast, asts, code, task;
      asts = null;
      code = null;
      try {
        ast = this.parser.parse(stmt);
        code = this.compiler.compile(ast, this.baseEnv);
        task = new Task(code, this.baseEnv);
        return task.run(cb);
      } catch (e) {
        loglet.log('VM.evalError', stmt, asts, code);
        return cb(e);
      }
    };

    return VM;

  })();

  module.exports = VM;

}).call(this);