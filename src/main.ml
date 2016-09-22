
(* This file is free software, part of dolmen. See file "LICENSE" for more information *)

module M = Logic.Make(ParseLocation)(Id)(Term)(Statement)

let help_msg =
"Small utility to parse various file formats.

Usage: `dolmen [options] file`
The file format is guessed based on the extension of the file name."

let parse_opts () =
  let input = ref (`Stdin M.Smtlib) in
  let print = ref false in
  let mode = ref `Regular in
  let set_file f = match !input with
    | `Stdin _ -> input := `File f
    | `File _ -> failwith "can only parse one file"
  in
  let opts =
    Arg.align [
      "--print", Arg.Set print, " print the parsed statements and format";
      "--interactive", Arg.Unit (fun () -> mode := `Interactive),
        " parse the file in interactive mode";
    ]
  in
  Arg.parse opts set_file help_msg;
  !input, !print, !mode

let handle_exn = function
  | ParseLocation.Lexing_error (pos, lexeme) ->
    Format.printf "%a@\nLexing error, unrecognised lexeme: '%s'@."
      ParseLocation.fmt pos lexeme
  | ParseLocation.Syntax_error (pos, "") ->
    Format.printf "%a@\nSyntax error.@." ParseLocation.fmt pos
  | ParseLocation.Syntax_error (pos, msg) ->
    Format.printf "%a@\nSyntax error: %s@." ParseLocation.fmt pos msg
  | ParseLocation.Uncaught (pos, e) ->
    Format.printf "%a@\n%s@." ParseLocation.fmt pos (Printexc.to_string e)
  | e ->
    Format.printf "Unexpect exception (really bad!):@\n%s@."
      (Printexc.to_string e)

let rec fold gen f acc =
  match gen () with
  | None | Some { Statement.descr = Statement.Exit } ->
    acc
  | exception e ->
    let () = handle_exn e in
    fold gen f false
  | Some s ->
    let () = f s in
    fold gen f acc

let () =
  let input, print, mode = parse_opts () in
  let lang, stmts =
    match mode with
    | `Regular ->
      begin match input with
        | `Stdin _ ->
          Format.printf "Reading stdin requires interactive mode@.";
          exit 3
        | `File f ->
          let lang, stmts = M.parse_file f in
          let l = ref stmts in
          lang, (fun () -> match !l with
              | [] -> None
              | s :: r -> l := r; Some s)
      end
    | `Interactive ->
      M.parse_input input
  in
  if print then
    begin match input with
      | `File f -> Format.printf "reading: %s@." f
      | `Stdin _ -> Format.printf "reading: stdin@."
    end;
  if print then
    Format.printf "guessed format : %s@." (M.string_of_language lang);
  let ok = fold stmts (fun s ->
      if print then
        Format.fprintf Format.std_formatter "%a@." Statement.print s
    ) true in
  if ok then
    Format.printf "ok@."
  else
    exit 2

