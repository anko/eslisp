{ Transform } = require \stream
module.exports = lex = ->

  token = ""
  in-string = false
  escaped = false
  in-comment = false

  stream = new Transform { +object-mode }
    .._transform = (chunk, _, cb) ->
      chunk .= to-string!

      emit = (token-name) ->
        stream.push do
          name : token-name
          content : token.length and token or null
        token := ""

      break-identifier = ->
        return if in-comment or in-string
        if token.length
          emit \IDENTIFIER
      break-comment = ->
        return unless in-comment
        emit \COMMENT

      for i til chunk.length

        char = chunk[i]
        #console.log char, ": #token"

        if in-string
          switch char
          | \" => # double quote
            if escaped
              token += char
              escaped := false
            else
              emit \LIT_STRING
              in-string := false
              token := ""
          | \\ => # backslash
            if escaped
              token += char
              escaped := false
            else
              escaped := true
          | otherwise =>
            if escaped
              escaped := false
              switch char
              | \n => token += "\n"
              | \r => token += "\r"
              | \t => token += "\t"
              | _  =>
                # Other characters may not be escaped
                return cb "Invalid escape '\\#char'"
            else token += char

        else
          switch char
          | \( =>
            break-identifier!
            emit \L_PAREN
          | \) =>
            break-identifier!
            emit \R_PAREN
          | "\r"  => fallthrough
          | "\n"  =>
            break-comment!
            fallthrough
          | " "   => fallthrough
          | "\t"  =>
            break-identifier!
          | otherwise =>
            switch char
            | \" => in-string := true
            | _  => token += char
      cb!
