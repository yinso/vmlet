{
  
  var indentStack = [];
  var currentIndent = '';
}

start
  = INDENT? l:line
    { return l; }

line
  = SAMEDENT line:(!EOL c:. { return c; })+ EOL?
    children:( INDENT c:line* DEDENT { return c; })?
    { var o = {}; o[line] = children; return children ? o : line.join(""); }

EOL
  = "\r\n" / "\n" / "\r"

SAMEDENT
  = i:[ \t]* &{ return i.join("") === currentIndent; }

INDENT
  = &(i:[ \t]+ &{ return i.length > currentIndent.length; }
      { indentStack.push(currentIndent); currentIndent = i.join(""); pos = offset; })

DEDENT
  = { currentIndent = indentStack.pop(); }
