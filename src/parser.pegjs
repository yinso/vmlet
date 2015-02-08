/************************************************************************
HELPER FUNCTIONS
************************************************************************/
{
  var helper = require('./parser-helper');
}
 
/************************************************************************
TopLevel
************************************************************************/
start
= _ exps:Expression* _ {
  if (exps.length == 1)
    return exps[0];
  else 
    return helper.block(exps);
}

Keywords
= 'if'
/ 'then'
/ 'else'
/ 'and'
/ 'or'
/ 'begin'
/ 'end'
/ 'true'
/ 'false'
/ 'null'
/ 'function'
/ 'func'
/ 'procedure'
/ 'proc'
/ 'define'
/ 'set'
/ 'throw'
/ 'try'
/ 'catch'
/ 'finally'

Expression
= exp:IfExp _ { return exp; }
/ op:OperatorExp _ { return op; }
/ exp:MemberExp _ { return exp ; }
/ n:NumberExp _ { return n; }
/ str:StringExp _ { return str; }
/ bool:BoolExp _ { return bool; }
/ n:NullExp _ { return n; }
/ sym:SymbolExp _ { return sym; }
/ obj:ObjectExp _ { return obj; }
/ ary:ArrayExp _ { return ary; }
/ block:BlockExp _ { return block; }
/ t:ThrowExp _ { return t; }
/ t:TryCatchExp _ { return t; }
/ define:DefineExp _ { return define; }
/ func:FunctionDeclExp _ { return func; }

/************************************************************************
DefineExp
************************************************************************/
DefineExp
= 'define' _ id:SymbolExp _ '=' _ exp:Expression _ { return helper.define(id, exp); }

/************************************************************************
FunctionDeclExp
************************************************************************/
FunctionDeclExp
= functionDeclHeadExp _ id:SymbolExp? _ params:funcParametersExp _ exp:Expression { return helper.function(id, params,exp); }

functionDeclHeadExp 
= 'function' / 'func' / 'procedure' / 'proc'

funcParametersExp
= '(' _ params:funcParameterExp* _ ')' _ { return params; }

funcParameterExp
= param:SymbolExp _ ','? _ { return helper.param(param.val); }

/************************************************************************
ThrowExp
************************************************************************/
ThrowExp
= 'throw' _ e:Expression _ { return helper.throw(e); }

/************************************************************************
TryCatchExp
************************************************************************/
TryCatchExp
= 'try' _ body:Expression _ catches:catchExp* _ fin:finallyExp? _ { return helper.try(body, catches, fin); }

catchExp
= 'catch' _ param:catchParamExp _ body:Expression _ { return helper.catch(param, body); }

catchParamExp
= '(' _ param:funcParameterExp _ ')' _ { return param; }

finallyExp
= 'finally' _ body:Expression _ { return helper.finally(body); }

/************************************************************************
OperatorExp

This determines the precedences of the operators.
************************************************************************/
OperatorExp 
= OrExp

OrExp
= lhs:AndExp _ rest:orRestExp* _ { return helper.operator(lhs, rest); }

orRestExp
= op:('||' / 'or') _ rhs:AndExp _ { return {op: 'or', rhs: rhs}; }

AndExp
= lhs:CompareExp _ rest:andRestExp* _ { return helper.operator(lhs, rest); }

andRestExp
= op:('&&' / 'and') _ rhs:CompareExp _ { return {op: 'and', rhs: rhs}; }

CompareExp
= lhs:AddExp _ rest:compareRestExp* _ { return helper.operator(lhs, rest); }

compareRestExp
= op:('==' / '!=' / '>=' / '>' / '<=' / '<') _ rhs:AddExp _ { return {op: op, rhs: rhs}; }

AddExp
= lhs:MultiplyExp _ rest:addRestExp* _ { return helper.operator(lhs, rest); }

addRestExp
= op:('+' / '-') _ rhs:MultiplyExp _ { return {op: op, rhs: rhs}; }

MultiplyExp
= lhs:AtomicExp _ rest:multiplyRestExp* _ { return helper.operator(lhs, rest); }

multiplyRestExp 
= op:('*' / '/' / '%') _ rhs:AtomicExp _ { return {op: op, rhs: rhs}; }


/************************************************************************
IfExp
************************************************************************/
IfExp
= 'if' _ condExp:Expression 'then'? _ thenExp:Expression _ 'else'? _ elseExp:Expression _ { return helper.if(condExp, thenExp, elseExp); }

/************************************************************************
BlockExp
************************************************************************/
BlockExp
= '{' _ exps:Expression* _'}' { return helper.block(exps); }

/************************************************************************
AtomicExp

These are expressions that has the highest parsing precedence.
************************************************************************/
AtomicExp
= exp:MemberExp _ { return exp ; }
/ n:NumberExp _ { return n; }
/ str:StringExp _ { return str; }
/ bool:BoolExp _ { return bool; }
/ sym:SymbolExp _ { return sym; }
/ parened:ParenedExp _ { return parened; }

ParenedExp
= '(' _ exp:Expression _ ')' _ { return exp; }

/************************************************************************
BoolExp
************************************************************************/
BoolExp
= 'true' _ { return helper.bool(true); }
/ 'false' _ { return helper.bool(false); }

/************************************************************************
NullExp
************************************************************************/
NullExp
= 'null' _ { return helper.null(); }

/************************************************************************
SymbolExp
************************************************************************/
SymbolExp 
= !Keywords c1:symbol1stChar rest:symbolRestChar* { return helper.symbol(c1, rest); }

symbol1stChar
= [^ \t\n\r\-0-9\(\)\;\ \"\'\,\`\{\}\.\,\:\[\]]

symbolRestChar
= [^ \t\n\r\(\)\;\ \"\'\,\`\{\}\.\,\:\[\]]

/************************************************************************
MemberExp
************************************************************************/
MemberExp
= head:memberHeadExp _ keys:memberKeyExp* { return helper.member(head, keys); }

memberHeadExp
= num:NumberExp _ { return num; }
/ str:StringExp _ { return str; }
/ ary:ArrayExp _ { return ary; }
/ bool:BoolExp _ { return bool; }
/ n:NullExp _ { return n; }
/ sym:SymbolExp _ { return sym; }
/ obj:ObjectExp _ { return obj; }
/ p:ParenedExp _ { return p; }

memberKeyExp
= '.' _ exp:SymbolExp _ { return exp; }
/ '[' _ exp:Expression _ ']' _ { return exp; }
/ argumentsExp

argumentsExp
= '(' args:argumentExp* ')' { return helper.arguments(args); }

argumentExp
= arg:Expression _ ','? _ { return arg; }

/************************************************************************
ObjectExp
************************************************************************/
ObjectExp
= '{' keyVals:keyValExp* '}' _ { return helper.object(keyVals); }

keyValExp
= key:keyExp _ ':' _ val:Expression _ keyValDelim? { return [ key, val ]; }

keyValDelim
= ',' _ { return ',' }

keyExp
= s:SymbolExp { return s.val; }
/ s:StringExp { return s; }

/************************************************************************
ArrayExp
************************************************************************/
ArrayExp
= '[' _ items:arrayItemExp* _ ']' { return helper.array(items); }

arrayItemExp
= item:Expression _ keyValDelim? { return item; }

/************************************************************************
StringExp
************************************************************************/
StringExp
= '"' chars:doubleQuoteChar* '"' _ { return helper.string(chars); }

singleQuoteChar
= '"'
/ char

doubleQuoteChar
= "'"
/ char

char
// In the original JSON grammar: "any-Unicode-character-except-"-or-\-or-control-character"
= [^"'\\\0-\x1F\x7f]
/ '\\"'  { return '"';  }
/ "\\'"  { return "'"; }
/ "\\\\" { return "\\"; }
/ "\\/"  { return "/";  }
/ "\\b"  { return "\b"; }
/ "\\f"  { return "\f"; }
/ "\\n"  { return "\n"; }
/ "\\r"  { return "\r"; }
/ "\\t"  { return "\t"; }
/ whitespace 
/ "\\u" digits:hexDigit4 {
  return String.fromCharCode(parseInt("0x" + digits));
}

hexDigit4
= h1:hexDigit h2:hexDigit h3:hexDigit h4:hexDigit { return h1+h2+h3+h4; }

/************************************************************************
NumberExp
************************************************************************/
NumberExp
= int:int frac:frac exp:exp _ { 
  return helper.number(int, frac, exp);
}
/ int:int frac:frac _     { 
  return helper.number(int, frac, '');
}
/ '-' frac:frac _ { 
  return helper.number('-', frac, '');
}
/ frac:frac _ { 
  return helper.number('', frac, '');
}
/ int:int exp:exp _      { 
  return helper.number(int, '', exp);
}
/ int:int _          { 
  return helper.number(int, '', '');
}

int
  = digits:digits { return digits.join(''); }
  / "-" digits:digits { return ['-'].concat(digits).join(''); }

frac
  = "." digits:digits { return ['.'].concat(digits).join(''); }

exp
  = e digits:digits { return ['e'].concat(digits).join(''); }

digits
  = digit+

e
  = [eE] [+-]?

digit
  = [0-9]

digit19
  = [1-9]

hexDigit
  = [0-9a-fA-F]


/************************************************************************
Whitespace
************************************************************************/
_ "whitespace"
= whitespace*

// Whitespace is undefined in the original JSON grammar, so I assume a simple
// conventional definition consistent with ECMA-262, 5th ed.
whitespace
= comment
/ [ \t\n\r]


lineTermChar
= [\n\r\u2028\u2029]

lineTerm "end of line"
= "\r\n"
/ "\n"
/ "\r"
/ "\u2028" // line separator
/ "\u2029" // paragraph separator

sourceChar
= .

/************************************************************************
Comment
************************************************************************/
comment
= multiLineComment
/ singleLineComment

singleLineCommentStart
= '//' // c style

singleLineComment
= singleLineCommentStart chars:(!lineTermChar sourceChar)* lineTerm? { 
  return {comment: chars.join('')}; 
}

multiLineComment
= '/*' chars:(!'*/' sourceChar)* '*/' { return {comment: chars.join('')}; }