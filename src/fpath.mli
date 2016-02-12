(*---------------------------------------------------------------------------
   Copyright 2014 Daniel C. Bünzli. All rights reserved.
   Distributed under the BSD3 license, see license at the end of the file.
   %%NAME%% release %%VERSION%%
  ---------------------------------------------------------------------------*)

(** File system paths, file {{!file_exts}extensions}, path {{!Set}sets}
    and {{!Map}maps}.

    A (file system) {e path} specifies a file or a directory in a file
    system hierarchy. A path has three parts:
    {ol
    {- An optional, platform-dependent, {{!split_volume}volume}.}
    {- An optional root directory separator {!dir_sep} whose presence
        distinguishes {e absolute} paths (["/a"]) from {e relative}
        ones (["a"])}
    {- A non-empty list of {!dir_sep} separated segments. Segments are
       non empty strings except for maybe the last one. The latter
       distinguishes {e directory paths}
       (["a/b/"]) from {e file paths} (["a/b"]).}}

    Consult a few {{!tips}important tips}.

    {b Note.} [Fpath] processes paths without accessing the file system.

    {e v%%VERSION%% - {{:%%PKG_WWW%% }homepage}} *)

open Astring

(** {1:paths Paths} *)

val dir_sep : string
(** [dir_sep] is the platform dependent directory separator.  This is
    ["/"] on POSIX and ["\\"] on Windows. *)

val is_seg : string -> bool
(** [is_seg s] is [true] iff [s] does not contain {!dir_sep} or a
    [0x00] byte. *)

type t
(** The type for paths. *)

val v : string -> t
(** [v s] is the string [s] as path.

    @raise Invalid_argument if [s] is not a {{!of_string}valid path}. Use
    {!of_string} to deal with foreign input and errors. *)

val add_seg : t -> string -> t
(** [add_seg p seg] adds [seg] at the end of [p]. If [seg] is [""]
    it is only added if [p] has no final empty segment. {{!ex_add_seg}Examples}.

    @raise Invalid_argument if {!is_seg}[ seg] is [false]. *)

val ( / ) : t -> string -> t
(** [p / seg] is {!add_seg}[ p seg]. Left associative. *)

val append : t -> t -> t
(** [append p p'] appends [p'] to [p] as follows:
    {ul
    {- If [p'] is absolute or has a non-empty {{!split_volume}volume} then
       [p'] is returned.}
    {- Otherwise appends [p'] to [p] using a {!dir_sep} if needed.}}
    {{!ex_append}Examples}. *)

val ( // ) : t -> t -> t
(** [p // p'] is {!append}[ p p']. Left associative. *)

val split_volume : t -> string * t
(** [split_volume p] is the pair [(vol, q)] where [vol] is
    the platform dependent volume of [p] or the empty string
    if there is none and [q] the path [p] without its volume, that is
    its optional root {!dir_sep} and segments.

    On POSIX if [vol] is non-empty then it
    {{:http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_267}can} only be ["/"] (e.g. in [v "//a/b"]). On Windows [vol] may be
    one of the following prefixes parsed before an
    absolute root {!dir_sep}, except in the first case
    where a relative path can follow:
{[
$(drive):
\\$(server)\$(share)
\\?\$(drive):
\\?\$(server)\$(share)
\\?\UNC\$(server)\$(share)
\\.\$(device)
]}
    The following invariant holds:
    {ul
    {- [equal (v (vol ^ (to_string q))) p]}} *)

val segs : t -> string list
(** [segs p] is [p]'s {e non-empty} list of segments. Absolute paths have an
    initial empty string added, this allows to recover the path's string with
    {!String.concat}[ ~sep:dir_sep]. {{!ex_segs}Examples.}

    The following invariant holds:
    {ul
    {- [to_string (snd (split_volume p)) = (String.concat ~sep:dir_sep
       (segs p))]}} *)

(** {1:filedir File and directory paths} *)

val is_dir_path : t -> bool
(** [is_dir_path p] is [true] iff [p] represents a directory. This means
    that [p]'s last segment is either [""], ["."] or [".."].
    {{!ex_is_dir_path}Examples}. *)

val is_file_path : t -> bool
(** [is_file_path p] is [true] iff [p] represents a file. This is the
    negation of {!is_dir_path}. This means that [p]'s last segment is
    neither empty nor ["."], nor [".."]. {{!ex_is_file_path}Examples}. *)

val to_dir_path : t -> t
(** [to_dir_path p] is {!add_seg}[ p ""] it ensure that the result
    represents a {{!is_dir_path}directory} (and, if converted to
    a string, that it will end with a {!dir_sep}).
    {{!ex_to_dir_path}Examples}. *)

val filename : t -> string
(** [filename p] is the file name of [p]. This is the last segment of
    [p] if [p] is a {{!is_file_path}file path} and the empty string
    otherwise. See also {!name}. {{!ex_filename}Examples}. *)

(** {1:parentbase Base and parent paths} *)

val split_base : t -> t * t
(** [split_base p] splits [p] into a directory [d] and a {e relative}
    base path [b] such that:
    {ul
    {- [b] is a relative path that contains the segments of [p]
       that start at the last non-empty segment. This means
       that [b] has a {e single} non-empty segment, and preserves
       {{!is_dir_path}directoryness} of [p]. If [p] is a
       {{!is_root}root path} there are no such segments and [b]
       is ["./"].}
    {- [d] is a {{!is_dir_path}directory} such that [d // b]
       represents the same path as [p] (it may however differ
       syntactically when converted to a string).}}

    {{!ex_split_base}Examples}. *)

val base : t -> t
(** [base p] is [snd (split_base p)]. *)

val basename : t -> string
(** [basename p] is the last non-empty, non-relative (i.e. not ["."]
    or [".."]) segment of [p] or the empty string. The latter occurs on
    {{!is_root}root paths} and on paths whose last non-empty segment is
    relative. See also {!filename} and {!base}. {{!ex_basename}Examples}. *)

val parent : t -> t
(** [parent p] is a {{!is_dir_path}directory path} that contains [p].
    If [p] is a {{!is_root}root path} this is [p] itself.
    {{!ex_parent}Examples}.

    {b Warning.} [parent p // base p] may not represent [p], use
    {!split_base} for this. *)

(** {1:norm Normalization} *)

val rem_empty_seg : t -> t
(** [rem_empty_seg p] removes the empty segment of [p] if it
    exists and [p] is not a {{!is_root}root path}. This ensure that if
    [p] is converted to a string it will not have a trailing
    {!dir_sep} unless [p] is a root path. Note that this may affect
    [p]'s {{!is_dir_path}directoryness}.
    {{!ex_rem_empty_seg}Examples}. *)

val normalize : t -> t
(** [normalize p] is a path that represents the same path as [p],
    {{!is_dir_path}directoryness} included, and that has the following
    properties:
    {ul
    {- If [p] is absolute the resulting path has no ["."] and [".."]
       segments.}
    {- If [p] is relative the resulting path is either ["./"] or
       it has no ["."] segments and [".."] segments may only appear as
       initial segments.}}
    {{!ex_normalize}Examples}. *)

(** {1:prefix Prefixes, roots and relativization} *)

val is_prefix : root:t -> t -> bool
(** [is_prefix ~root p] is [true] if [root] is a prefix of [p].  This
    checks that [root] has the same optional volume as [p], the same
    optional root directory separator and that the list of segments
    of [root] is a prefix of the segments of [p]. {{!ex_is_prefix}Examples}. *)

val find_prefix : t -> t -> t option
(** [find_prefix p p'] is [Some root] if there exists [root] such that
    [root] is the longest path with
    [is_prefix root p && is_prefix root p' = true] and [None] otherwise.
    Note that if both [p] and [p'] are relative or absolute
    and have the same volume then a prefix exists.
    {{!ex_find_prefix}Examples}. *)

val rem_prefix : root:t -> t -> t option
(** [rem_prefix root p] is [Some q] if [root] is a
    {{!is_prefix}prefix} of [p]; [q] is [p] without the [root]
    prefix but interpreted as a {{!file_to_dir}directory} (hence [q]
    is always relative). {{!ex_rem_prefix}Examples}.

    {b Note.} If you {{!find_prefix}find} a prefix and this
    prefix is ["."], [rem_prefix] may return [None] on that
    prefix and the path where you found it. *)

val rooted : root:t -> t -> t option
(** [rooted ~root p] is:
    {ul
    {- [None] if
       [is_prefix (normalize root) (normalize @@ append root p) = false].}
    {- [Some (normalize @@ append root p)] otherwise.}}
       In other words it ensures that an absolute path [p] or a relative
       path [p] expressed w.r.t. [root] expresses a path that is
       within the [root] file hierarchy. {{!ex_rooted}Examples}. *)

val relativize : root:t -> t -> t option
(** [relativize ~root p] expresses [p] relative to [root] without
    consulting the file system. This is:
    {ul
    {- [None] if [find_prefix (normalize root) (normalize p)] is [None] or
       if the number of initial relative [..] segments is larger in
       [(normalize root)] than in [normalize p] (intuitively you can't
       come back from [root] to [p] without knowing the absolute path to
       the current working directory).}
    {- [Some q] otherwise with [q] such that
       [equal (normalize (append root q)) (normalize p) = true].}}
       {{!ex_relativize}Examples.} *)

(** {1:predicates Predicates and comparison} *)

val is_rel : t -> bool
(** [is_rel p] is [true] iff [p] is a relative path, i.e. the root
    directory separator is missing in [p]. *)

val is_abs : t -> bool
(** [is_abs p] is [true] iff [p] is an absolute path, i.e. the root
    directory separator is present in [p]. *)

val is_root : t -> bool
(** [is_root p] is [true] iff [p] is a root directory, i.e. [p] has the
    root directory separator and a single, empty, segment.
    {{!ex_is_root}Examples}.

    {b Warning.} By definition this is a structural test. For example it will
    return [false] on ["/a/.."] or ["/.."]. {{!normalize}Normalizing}
    the path before testing avoids this problem. *)

val is_current_dir : t -> bool
(** [is_current_dir p] is true iff [p] is the current relative directory,
    i.e. either ["."] or ["./"]. {{!ex_is_current_dir}Examples}.

    {b Warning.} By definition this is a structural test. For example it will
    return [false] on ["./a/.."] or ["./."]. {{!normalize}Normalizing} the
    path before testing avoids this problem. *)

val is_dotfile : t -> bool
(** [is_dotfile p] is [true] iff [p]'s last non-empty segment is not
    ["."] or [".."] and starts with a ['.']. {{!ex_is_dotfile}Examples}.

    {b Warning.} By definition this is a structural test. For example it will
    return [false] on [".ssh/."]. {{!normalize}Normalizing} the
    path before testing avoids this problem. *)

val equal : t -> t -> bool
(** [equal p p'] is [true] if [p] and [p'] have the same volume
    are both relative or absolute and have the same segments.

    {b Warning.} By definition this is a structural test. For example
    [equal (v "./") (v "a/..")] is [false]. {{!normalize}Normalizing}
    the paths before testing avoids this problem. *)

val compare : t  -> t -> int
(** [compare p p'] is a total order on paths compatible with {!equal}. *)

(** {1:conversions Conversions and pretty printing} *)

val to_string : t -> string
(** [to_string p] is the path [p] as a string. The result can
    be safely converted back with {!v}. *)

val of_string : string -> t option
(** [of_string s] is the string [s] as a path. [None] is returned if
    {ul
    {- [s] or the path following the {{!split_volume}volume} is empty ([""]),
       expect on Windows UNC paths, see below.}
    {- [s] has null byte (['\x00']).}
    {- On Windows, [s] is an invalid UNC path (e.g. ["\\\\"] or ["\\\\a"])}}
    The following transformations are performed on the string:
    {ul
    {- On Windows any ['/'] occurence is converted to ['\\'] before
       any processing occurs.}
    {- Non-initial empty segments are suppressed;
       ["a//b"] becomes ["a/b"], ["//a////b//"] becomes ["//a/b/"], etc.}
    {- On Windows empty absolute UNC paths are completed to
       their root. For example ["\\\\server\\share"] becomes
       ["\\\\server\\share\\"],
       but incomplete UNC volumes like ["\\\\a"] return [None].}} *)

val pp : Format.formatter -> t -> unit
(** [pp ppf p] prints path [p] on [ppf] using {!to_string}. *)

val dump : Format.formatter -> t -> unit
(** [dump ppf p] prints path [p] on [ppf] using {!String.dump}. *)

(** {1:file_exts File extensions}

    The {e file extension} (resp. {e multiple file extension}) of a
    path segment is the suffix that starts at the last (resp. first)
    occurence of a ['.'] that is preceeded by at least one non ['.']
    character.  If there is no such occurence in the segment, the
    extension is empty.  With these definitions, ["."], [".."],
    ["..."] and dot files like [".ocamlinit"] or ["..ocamlinit"] have
    no extension, but [".emacs.d"] and ["..emacs.d"] do have one. *)

type ext = string
(** The type for file extensions. *)

val get_ext : ?multi:bool -> t -> ext
(** [get_ext p] is [p]'s last segment file extension or the empty
    string if there is no extension. If [multi] is [true] (defaults to
    [false]), returns the multiple file extension. {{!ex_get_ext}Examples}. *)

val has_ext : ext -> t -> bool
(** [has_ext e p] is [true] iff [ext p = e || ext ~multi:true p = e].
    If [e] doesn't start with a ['.'] one is prefixed before making
    the test. {{!ex_has_ext}Examples}. *)

val ext_exists : ?multi:bool -> t -> bool
(** [ext_exists ~multi p] is [true] iff [p]'s last segment has an
    extension.  If [multi] is [true] (default to [false]) returns
    [true] iff [p] has {e more than one} extension.
    {{!ex_ext_exists}Examples}. *)

val add_ext : ext -> t -> t
(** [add_ext ext p] is [p] with the string [ext] concatenated to [p]'s
    last segment. If [ext] doesn't start with a ['.'] one is prefixed to it
    before concatenation except if [ext] is [""]. {{!ex_add_ext}Examples}.

    @raise Invalid_argument if {!is_seg}[ ext] is [false]. *)

val rem_ext : ?multi:bool -> t -> t
(** [rem_ext p] is [p] with the file extension of [p]'s last segment
    removed. If [multi] is [true] (default to [false]), the multiple
    file extension is removed. {{!ex_rem_ext}Examples}. *)

val set_ext : ?multi:bool -> ext -> t -> t
(** [set_ext ?multi p ext] is [add_ext ext (rem_ext ?multi p)].

    @raise Invalid_argument if {!is_seg}[ ext] is [false]. *)

val split_ext : ?multi:bool -> t -> t * ext
(** [split_ext ?multi p] is [(rem_ext ?multi p, ext ?multi p)].

    Using [(p', ext)] for the resulting pair, the following invariant
    holds:
    {ul
    {- [equal (v (to_string p' ^ ext)) p]}} *)

val ( + ) : t -> ext -> t
(** [p + ext] is [add_ext ext p]. Left associative. *)

val ( -+ ) : t -> ext -> t
(** [p -+ ext] is [set_ext ext p]. Left associative. *)

(** {1:sets_maps Path sets and maps} *)

type path = t

type set
(** The type for path sets *)

(** Path sets. *)
module Set : sig

  (** {1 Path sets} *)

  include Set.S with type elt := path
                 and type t := set

  type t = set

  val min_elt : set -> path option
  (** Exception safe {!Set.S.min_elt}. *)

  val get_min_elt : set -> path
  (** [get_min_let] is like {!min_elt} but @raise Invalid_argument
        on the empty set. *)

  val max_elt : set -> path option
  (** Exception safe {!Set.S.max_elt}. *)

  val get_max_elt : set -> path
  (** [get_max_elt] is like {!max_elt} but @raise Invalid_argument
        on the empty set. *)

  val choose : set -> path option
  (** Exception safe {!Set.S.choose}. *)

  val get_any_elt : set -> path
  (** [get_any_elt] is like {!choose} but @raise Invalid_argument on the
        empty set. *)

  val find : path -> set -> path option
  (** Exception safe {!Set.S.find}. *)

  val get : path -> set -> path
  (** [get] is like {!Set.S.find} but @raise Invalid_argument if
        [elt] is not in [s]. *)

  val of_list : path list -> set
  (** [of_list ps] is a set from the list [ps]. *)

  val pp : ?sep:(Format.formatter -> unit -> unit) ->
    (Format.formatter -> string -> unit) ->
    Format.formatter -> set -> unit
  (** [pp ~sep pp_elt ppf ps] formats the elements of [ps] on
        [ppf]. Each element is formatted with [pp_elt] and elements
        are separated by [~sep] (defaults to
        {!Format.pp_print_cut}). If the set is empty leaves [ppf]
        untouched. *)

  val dump : Format.formatter -> set -> unit
  (** [dump ppf ps] prints an unspecified representation of [ps] on
        [ppf]. *)
end

type +'a map
(** The type for maps from paths to values of type ['a]. *)

(** Path maps. *)
module Map : sig

  (** {1 Path maps} *)

  include Map.S with type key := t
                 and type 'a t := 'a map

  type 'a t = 'a map

  val min_binding : 'a map -> (path * 'a) option
  (** Exception safe {!Map.S.min_binding}. *)

  val get_min_binding : 'a map -> (path * 'a)
  (** [get_min_binding] is like {!min_binding} but @raise Invalid_argument
      on the empty map. *)

  val max_binding : 'a map -> (path * 'a) option
  (** Exception safe {!Map.S.max_binding}. *)

  val get_max_binding : 'a map -> string * 'a
  (** [get_min_binding] is like {!max_binding} but @raise Invalid_argument
      on the empty map. *)

  val choose : 'a map -> (path * 'a) option
  (** Exception safe {!Map.S.choose}. *)

  val get_any_binding : 'a map -> (path * 'a)
  (** [get_any_binding] is like {!choose} but @raise Invalid_argument
      on the empty map. *)

  val find : path -> 'a map -> 'a option
  (** Exception safe {!Map.S.find}. *)

  val get : path -> 'a map -> 'a
  (** [get k m] is like {!Map.S.find} but raises [Invalid_argument] if
      [k] is not bound in [m]. *)

  val dom : 'a map -> set
  (** [dom m] is the domain of [m]. *)

  val of_list : (path * 'a) list -> 'a map
  (** [of_list bs] is [List.fold_left (fun m (k, v) -> add k v m) empty
      bs]. *)

  val pp : ?sep:(Format.formatter -> unit -> unit) ->
    (Format.formatter -> path * 'a -> unit) -> Format.formatter ->
    'a map -> unit
  (** [pp ~sep pp_binding ppf m] formats the bindings of [m] on
      [ppf]. Each binding is formatted with [pp_binding] and
      bindings are separated by [sep] (defaults to
      {!Format.pp_print_cut}). If the map is empty leaves [ppf]
      untouched. *)

  val dump : (Format.formatter -> 'a -> unit) -> Format.formatter ->
    'a map -> unit
  (** [dump pp_v ppf m] prints an unspecified representation of [m] on
        [ppf] using [pp_v] to print the map codomain elements. *)
end

(** {1:tips Tips}

    {ul
    {- The documentation often talks about the last non-empty segment of
       a path. This usually means that we don't care whether the path
       is a {{!is_file_path}file path} (e.g. ["a"]) or a
       {{!is_dir_path}directory path} (e.g. ["a/"]).}
    {- Windows accepts both ['\\'] and ['/'] as directory
       separator.  However [Fpath] on Windows converts ['/'] to ['\\'] on
       the fly. Therefore you should either use ['/'] for defining
       constant paths you inject with {!v} or better, construct them
       directly with {!(/)}. {!to_string} will convert these paths
       to strings using the platform's specific directory
       separator {!dir_sep}.}
    {- Avoid platform specific {{!split_volume}volumes} or hard-coding file
       hierarchy conventions in your constants.}
    {- Do not assume there is a single root path and that it is
       [/]. On Windows each {{!split_volume}volume} can have a root path.
       Use {!is_root} to detect root paths.}
    {- Do not use {!to_string} to construct URIs, {!to_string} uses
       {!dir_sep} to separate segments, on Windows this is ['\\'] which
       is not what URIs expect. Access the path segments directly
       with {!segs}, note that you will need to percent encode these.}}

    {1:ex Examples}

    {2:ex_add_seg {!add_seg}}

    {ul
    {- [equal (add_seg (v "/a") "b") (v "/a/b")]}
    {- [equal (add_seg (v "/a/") "b") (v "/a/b")]}
    {- [equal (add_seg (v "/a/b") "") (v "/a/b/")]}
    {- [equal (add_seg (v "/a/b/") "") (v "/a/b/")]}
    {- [equal (add_seg (v "/") "") (v "/")]}
    {- [equal (add_seg (v "/") "a") (v "/a")]}
    {- [equal (add_seg (v ".") "") (v "./")]}
    {- [equal (add_seg (v ".") "a") (v "./a")]}
    {- [equal (add_seg (v "..") "") (v "../")]}
    {- [equal (add_seg (v "..") "a") (v "../a")]}}

    {2:ex_append {!append}}

    {ul
    {- [equal (append (v "/a/b/") (v "e/f")) (v "/a/b/e/f")]}
    {- [equal (append (v "/a/b") (v "e/f")) (v "/a/b/e/f")]}
    {- [equal (append (v "/a/b/") (v "/e/f")) (v "/e/f")]}
    {- [equal (append (v "a/b/") (v "e/f")) (v "a/b/e/f")]}
    {- [equal (append (v "a/b") (v "C:e")) (v "C:e")] (Windows)}}

    {2:ex_segs {!segs}}

    {ul
    {- [segs (v "/a/b/") = [""; "a"; "b"; ""]]}
    {- [segs (v "/a/b") = [""; "a"; "b"]]}
    {- [segs (v "a/b/") = ["a"; "b"; ""]]}
    {- [segs (v "a/b") = ["a"; "b"]]}
    {- [segs (v "a") = ["a"]]}
    {- [segs (v "/") = [""; ""]]}
    {- [segs (v "\\\\.\\dev\\") = ["";""]] (Windows)}
    {- [segs (v "\\\\server\\share\\a") = ["";"a"]] (Windows)}
    {- [segs (v "C:a") = ["a"]] (Windows)}
    {- [segs (v "C:\\a") = ["";"a"]] (Windows)}}

    {2:ex_is_dir_path {!is_dir_path}}

    {ul
    {- [is_dir_path (v ".") = true]}
    {- [is_dir_path (v "..") = true]}
    {- [is_dir_path (v "../") = true]}
    {- [is_dir_path (v "/") = true]}
    {- [is_dir_path (v "/a/b/") = true]}
    {- [is_dir_path (v "/a/b") = false]}
    {- [is_dir_path (v "a/") = true]}
    {- [is_dir_path (v "a") = false]}
    {- [is_dir_path (v "a/.") = true]}
    {- [is_dir_path (v "a/..") = true]}
    {- [is_dir_path (v "a/..b") = false]}
    {- [is_dir_path (v "C:\\") = true] (Windows)}
    {- [is_dir_path (v "C:a") = false] (Windows)}}

    {2:ex_is_file_path {!is_file_path}}

    {ul
    {- [is_file_path (v ".") = false]}
    {- [is_file_path (v "..") = false]}
    {- [is_file_path (v "../") = false]}
    {- [is_file_path (v "/") = false]}
    {- [is_file_path (v "/a/b/") = false]}
    {- [is_file_path (v "/a/b") = true]}
    {- [is_file_path (v "a/") = false]}
    {- [is_file_path (v "a") = true]}©∂
    {- [is_file_path (v "a/.") = false]}
    {- [is_file_path (v "a/..") = false]}
    {- [is_file_path (v "a/..b") = true]}
    {- [is_file_path (v "C:\\") = false] (Windows)}
    {- [is_file_path (v "C:a") = true] (Windows)}}

    {2:ex_to_dir_path {!to_dir_path}}

    {ul
    {- [equal (to_dir_path @@ v ".") (v "./")]}
    {- [equal (to_dir_path @@ v "..") (v "../")]}
    {- [equal (to_dir_path @@ v "../") (v "../")]}
    {- [equal (to_dir_path @@ v "/") (v "/")]}
    {- [equal (to_dir_path @@ v "/a/b/") (v "/a/b/")]}
    {- [equal (to_dir_path @@ v "/a/b") (v "/a/b/")]}
    {- [equal (to_dir_path @@ v "a/") (v "a/")]}
    {- [equal (to_dir_path @@ v "a") (v "a/")]}
    {- [equal (to_dir_path @@ v "a/.") (v "a/./")]}
    {- [equal (to_dir_path @@ v "a/..") (v "a/../")]}
    {- [equal (to_dir_path @@ v "a/..b") (v "a/..b/")]}
    {- [equal (to_dir_path @@ v "\\\\server\\share\\")
       (v "\\\\server\\share\\")]
       (Windows)}
    {- [equal (to_dir_path @@ v "C:a") (v "C:a\\")] (Windows)}
    {- [equal (to_dir_path @@ v "C:\\") (v "C:\\")] (Windows)}}

    {2:ex_filename {!filename}}

    {ul
    {- [filename (v ".") = ""]}
    {- [filename (v "./") = ""]}
    {- [filename (v "..") = ""]}
    {- [filename (v "../") = ""]}
    {- [filename (v "../..") = ""]}
    {- [filename (v "/") = ""]}
    {- [filename (v "/a/b/") = ""]}
    {- [filename (v "/a/b") = "b"]}
    {- [filename (v "a/") = ""]}
    {- [filename (v "a") = "a"]}
    {- [filename (v "a/.") = ""]}
    {- [filename (v "a/..") = ""]}
    {- [filename (v "a/..b") = "..b"]}
    {- [filename (v "C:\\") = ""] (Windows)}
    {- [filename (v "C:a") = "a"] (Windows)}}

    {2:ex_split_base {!split_base}}

    {ul
    {- [(split_base @@ v ".") = (v "./"), (v ".")]}
    {- [(split_base @@ v "./") = (v "./"), (v "./")]}
    {- [(split_base @@ v "..") = (v "./"), (v "..")]}
    {- [(split_base @@ v "../") = (v "./"), (v "../")]}
    {- [(split_base @@ v "../../") = (v "../"), (v "../")]}
    {- [(split_base @@ v ".././") = (v "../"), (v "./")]}
    {- [(split_base @@ v "../../../") = (v "../../"), (v "../")]}
    {- [(split_base @@ v "/") = (v "/"), (v "./")]}
    {- [(split_base @@ v "/a/b/") = (v "/a/"), (v "b/")]}
    {- [(split_base @@ v "/a/b") = (v "/a/"), (v "b")]}
    {- [(split_base @@ v "a/") = (v "./"), (v "a/")]}
    {- [(split_base @@ v "a") = (v "./"), (v "a")]}
    {- [(split_base @@ v "a/b") = (v "a/"), (v "b")]}
    {- [(split_base @@ v "a/b/") = (v "a/b/"), (v "b/")]}
    {- [(split_base @@ v "a/.") = (v "a/"), (v ".")]}
    {- [(split_base @@ v "a/..") = (v "a/"), (v "..")]}
    {- [(split_base @@ v "a/../..") = (v "a/../"), (v "..")]}
    {- [(split_base @@ v "a/..b") = (v "a/"), (v "..b")]}
    {- [(split_base @@ v "./a") = (v "./"), (v "a")]}
    {- [(split_base @@ v "./a/") = (v "./"), (v "a/")]}
    {- [(split_base @@ v "../a") = (v "../"), (v "a")]}
    {- [(split_base @@ v "../a/") = (v "../"), (v "a/")]}}

    {2:ex_basename {!basename}}

    {ul
    {- [basename (v ".") = ""]}
    {- [basename (v "..") = ""]}
    {- [basename (v "../") = ""]}
    {- [basename (v "../../") = ""]}
    {- [basename (v "/") = ""]}
    {- [basename (v "/a/b/") = "b"]}
    {- [basename (v "/a/b") = "b"]}
    {- [basename (v "a/") = "a"]}
    {- [basename (v "a") = "a"]}
    {- [basename (v "a/.") = ""]}
    {- [basename (v "a/./") = ""]}
    {- [basename (v "a/..") = ""]}
    {- [basename (v "a/..b") = "..b"]}
    {- [basename (v "./a") = "a"]}
    {- [basename (v "../a") = "a"]}
    {- [basename (v "C:\\") = ""] (Windows)}
    {- [basename (v "C:a") = "a"] (Windows)}}

    {2:ex_parent {!parent}}

    {ul
    {- [equal (parent @@ v ".") (v "./../")]}
    {- [equal (parent @@ v "..") (v "../../")]}
    {- [equal (parent @@ v "../") (v "../../")]}
    {- [equal (parent @@ v "../../") (v "../../../")]}
    {- [equal (parent @@ v "/") (v "/")]}
    {- [equal (parent @@ v "/a/b/") (v "/a/")]}
    {- [equal (parent @@ v "/a/b") (v "/a/")]}
    {- [equal (parent @@ v "a/") (v "./")]}
    {- [equal (parent @@ v "a") (v "./")]}
    {- [equal (parent @@ v "a/.") (v "a/./../")]}
    {- [equal (parent @@ v "a/./") (v "a/./../")]}
    {- [equal (parent @@ v "a/..") (v "a/../../")]}
    {- [equal (parent @@ v "a/../") (v "a/../../")]}
    {- [equal (parent @@ v "a/..b") (v "a/")]}
    {- [equal (parent @@ v "./a") (v "./")]}
    {- [equal (parent @@ v "../a") (v "../")]}
    {- [equal (parent @@ v "../../a") (v "../../")]}
    {- [equal (parent @@ v "\\\\server\\share\\") (v "\\\\server\\share\\")]
       (Windows)}
    {- [equal (parent @@ v "C:\\") (v "C:\\")] (Windows)}
    {- [equal (parent @@ v "C:a") (v "C:.\\")] (Windows)}}

    {2:ex_rem_empty_seg {!rem_empty_seg}}

    {ul
    {- [equal (rem_empty_seg @@ v ".") (v ".")]}
    {- [equal (rem_empty_seg @@ v "..") (v "..")]}
    {- [equal (rem_empty_seg @@ v "../") (v "..")]}
    {- [equal (rem_empty_seg @@ v "../../") (v "../..")]}
    {- [equal (rem_empty_seg @@ v "/") (v "/")]}
    {- [equal (rem_empty_seg @@ v "/a/b/") (v "/a/b")]}
    {- [equal (rem_empty_seg @@ v "/a/b") (v "/a/b")]}
    {- [equal (rem_empty_seg @@ v "a/") (v "a")]}
    {- [equal (rem_empty_seg @@ v "a") (v "a")]}
    {- [equal (rem_empty_seg @@ v "a/.") (v "a/.")]}
    {- [equal (rem_empty_seg @@ v "a/./") (v "a/.")]}
    {- [equal (rem_empty_seg @@ v "a/..") (v "a/..")]}
    {- [equal (rem_empty_seg @@ v "a/../") (v "a/..")]}
    {- [equal (rem_empty_seg @@ v "a/..b") (v "a/..b")]}
    {- [equal (rem_empty_seg @@ v "./a") (v "./a")]}
    {- [equal (rem_empty_seg @@ v "../a") (v "../a")]}
    {- [equal (rem_empty_seg @@ v "../../a") (v "../../a")]}
    {- [equal (rem_empty_seg @@ v "\\\\server\\share\\")
    (v "\\\\server\\share\\")] (Windows)}
    {- [equal (rem_empty_seg @@ v "C:\\") (v "C:\\")] (Windows)}
    {- [equal (rem_empty_seg @@ v "C:a\\") (v "C:a")] (Windows)}}

    {2:ex_normalize {!normalize}}

    {ul
    {- [equal (normalize @@ v ".") (v "./")]}
    {- [equal (normalize @@ v "..") (v "..")]}
    {- [equal (normalize @@ v "../") (v "..")]}
    {- [equal (normalize @@ v "../../") (v "../..")]}
    {- [equal (normalize @@ v "/") (v "/")]}
    {- [equal (normalize @@ v "/a/b/") (v "/a/b/")]}
    {- [equal (normalize @@ v "/a/b") (v "/a/b")]}
    {- [equal (normalize @@ v "a/") (v "a/")]}
    {- [equal (normalize @@ v "a") (v "a")]}
    {- [equal (normalize @@ v "a/.") (v "a/")]}
    {- [equal (normalize @@ v "a/./") (v "a/")]}
    {- [equal (normalize @@ v "a/..") (v "./")]}
    {- [equal (normalize @@ v "a/../") (v "./")]}
    {- [equal (normalize @@ v "a/..b") (v "a/..b")]}
    {- [equal (normalize @@ v "./a") (v "a")]}
    {- [equal (normalize @@ v "../a") (v "../a")]}
    {- [equal (normalize @@ v "../../a") (v "../../a")]}
    {- [equal (normalize @@ v "./a/..") (v "./")]}
    {- [equal (normalize @@ v "/a/b/./..") (v "/a/")]}
    {- [equal (normalize @@ v "/../..") (v "/")]}
    {- [equal (normalize @@ v "/a/../..") (v "/")]}
    {- [equal (normalize @@ v "./../..") (v "../..")]}
    {- [equal (normalize @@ v "../../a/") (v "../../a/")]}
    {- [equal (normalize @@ v "/a/b/c/./../../g") (v "/a/g")]}
    {- [equal (normalize @@ v "/a/b/c/./../../g/") (v "/a/g/")]}
    {- [equal (normalize @@ v "\\\\?\\UNC\\server\\share\\..")
       (v "\\\\?\\UNC\\server\\share\\")] (Windows)}
    {- [equal (normalize @@ v "\\\\server\\share\\")
    (v "\\\\server\\share\\")] (Windows)}
    {- [equal (normalize @@ v "C:\\") (v "C:\\")] (Windows)}
    {- [equal (normalize @@ v "C:a\\") (v "C:a\\")] (Windows)}}

    {2:ex_is_prefix {!is_prefix}}

    {ul
    {- [is_prefix (v "/a/b") (v "/a/b") = true]}
    {- [is_prefix (v "/a/b") (v "/a/b/") = true]}
    {- [is_prefix (v "/a/b") (v "/a/bc") = false]}
    {- [is_prefix (v "/a/b") (v "/a/b/c") = true]}
    {- [is_prefix (v "/a/b/") (v "/a/b") = false]}
    {- [is_prefix (v "a/b") (v "/a/b") = false]}
    {- [is_prefix (v "a/b") (v "a/b") = true]}
    {- [is_prefix (v "//a/b") (v "/a/b") = false]}
    {- [is_prefix (v "C:a") (v "a") = false] (Windows)}}

    {2:ex_find_prefix {!find_prefix}}

    {ul
    {- [find_prefix (v "a/b/c") (v "a/b/d")] is [Some (v "a/b/")]}
    {- [find_prefix (v "a/b/c") (v "a/b/cd")] is [Some (v "a/b/")]}
    {- [find_prefix (v "/a/b/c") (v "/a/b/d")] is [Some (v "/a/b/")]}
    {- [find_prefix (v "a/b") (v "e/f")] is [Some (v ".")]}
    {- [find_prefix (v "/a/b") (v "/e/f")] is [Some (v "/")]}
    {- [find_prefix (v "/a/b") (v "e/f")] is [None]}
    {- [find_prefix (v "C:\\a") (v "\\a")] is [None] (Windows)}}

    {2:ex_rem_prefix {!rem_prefix}}

    {ul
    {- [rem_prefix (v "/a/b") (v "/a/bc")] is [None]}
    {- [rem_prefix (v "/a/b") (v "/a/b")] is [Some (v ".")]}
    {- [rem_prefix (v "/a/b/") (v "/a/b")] is [None]}
    {- [rem_prefix (v "/a/b") (v "/a/b/")] is [Some (v ".")]}
    {- [rem_prefix (v "/a/b/") (v "/a/b/")] is [Some (v ".")]}
    {- [rem_prefix (v "/a/b") (v "/a/b/c")] is [Some (v "c")]}
    {- [rem_prefix (v "/a/b/") (v "/a/b/c")] is [Some (v "c")]}
    {- [rem_prefix (v "a") (v "a/b/c")] is [Some (v "b/c")]}}

    {2:ex_rooted {!rooted}}

    {ul
    {- [rooted (v "/a/b") (v "c")] is [Some (v "/a/b/c")]}
    {- [rooted (v "/a/b") (v "/a/b/c")] is [Some (v "/a/b/c")]}
    {- [rooted (v "/a/b") (v "/a/b/c/")] is [Some (v "/a/b/c")]}
    {- [rooted (v "/a/b") (v "/a/b/c/.")] is [Some (v "/a/b/c")]}
    {- [rooted (v "/a/b") (v "../c")] is [None]}
    {- [rooted (v "a/b") (v "c")] is [Some (v "a/b/c")]}
    {- [rooted (v "a/b") (v "/c")] is [None]}
    {- [rooted (v "a/b") (v "../c")] is [None]}
    {- [rooted (v "a/b") (v "c/..")] is [Some (v "a/b")]}
    {- [rooted (v "a/b") (v "c/../..")] is [None]}}

    {2:ex_relativize {!relativize}}

    {ul
    {- [relativize (v "/a/b") (v "c")] is [None]}
    {- [relativize (v "/a/b") (v "/c")] is [Some (v "../../c")]}
    {- [relativize (v "/a/b") (v "/c/")] is [Some (v "../../c")]}
    {- [relativize (v "/a/b") (v "/a/b/c")] is [Some (v "c")]}
    {- [relativize (v "/a/b") (v "/a/b")] is [Some (v ".")]}
    {- [relativize (v "/a/b") (v "/a/b/")] is [Some (v ".")]}
    {- [relativize (v "a/b") (v "/c")] is [None].}
    {- [relativize (v "a/b") (v "c")] is [Some (v "../../c")]}
    {- [relativize (v "a/b") (v "c/")] is [Some (v "../../c")]}
    {- [relativize (v "a/b") (v "a/b/c")] is [Some (v "c")]}
    {- [relativize (v "a/b") (v "a/b")] is [Some (v ".")]}
    {- [relativize (v "a/b") (v "a/b/")] is [Some (v ".")]}
    {- [relativize (v "../a") (v "b")] is [None]}
    {- [relativize (v "../../a") (v "../b")] is [None]}
    {- [relativize (v "../a") (v "../../b")] is [(Some "../../b")]}}

    {2:ex_is_root {!is_root}}
    {ul
    {- [is_root (v "/") = true]}
    {- [is_root (v "/a") = false]}
    {- [is_root (v "/a/..") = false]}
    {- [is_root (v "//") = true] (POSIX)}
    {- [is_root (v "\\\\.\\dev\\") = true] (Windows)}
    {- [is_root (v "\\\\.\\dev\\a") = false] (Windows)}
    {- [is_root (v "\\\\server\\share\\") = true] (Windows)}
    {- [is_root (v "\\\\server\\share\\a") = false] (Windows)}
    {- [is_root (v "C:\\") = true] (Windows)}
    {- [is_root (v "C:a") = false] (Windows)}
    {- [is_root (v "C:\\a") = false] (Windows)}}

    {2:ex_is_current_dir {!is_current_dir}}
    {ul
    {- [is_current_dir (v ".") = true]}
    {- [is_current_dir (v "./") = true]}
    {- [is_current_dir (v "./a/..") = false]}
    {- [is_current_dir (v "./.") = false]}}

    {2:ex_is_dotfile {!is_dotfile}}
    {ul
    {- [is_dotfile (v ".ssh") = true]}
    {- [is_dotfile (v ".ssh/") = true]}
    {- [is_dotfile (v ".ssh/.") = false]}
    {- [is_dotfile (v ".ssh/a") = false]}}

    {2:ex_get_ext {!get_ext}}

    {ul
    {- [get_ext (v "/a/b") = ""]}
    {- [get_ext (v "a/.") = ""]}
    {- [get_ext (v "a/..") = ""]}
    {- [get_ext (v "a/.ocamlinit") = ""]}
    {- [get_ext (v "/a/b.") = "."]}
    {- [get_ext (v "/a/b.mli") = ".mli"]}
    {- [get_ext (v "a.tar.gz") = ".gz"]}
    {- [get_ext (v "a/.emacs.d") = ".d"]}
    {- [get_ext ~multi:true (v "/a/b.mli") = ".mli"]}
    {- [get_ext ~multi:true (v "a.tar.gz") = ".tar.gz"]}
    {- [get_ext ~multi:true (v "a/.emacs.d") = ".d"]}}

    {2:ex_has_ext {!has_ext}}

    {ul
    {- [has_ext ".mli" (v "a/b.mli")  = true]}
    {- [has_ext "mli" (v "a/b.mli")  = true]}
    {- [has_ext "mli" (v "a/bmli")  = false]}
    {- [has_ext ".tar.gz" (v "a/f.tar.gz") = true]}
    {- [has_ext "tar.gz" (v "a/f.tar.gz") = true]}
    {- [has_ext ".tar" (v "a/f.tar.gz") = false]}}

    {2:ex_ext_exists {!ext_exists}}

    {ul
    {- [ext_exists (v "a/f") = false]}
    {- [ext_exists (v "a/f.") = true]}
    {- [ext_exists (v "a/f.gz") = true]}
    {- [ext_exists (v "a/f.tar.gz") = true]}
    {- [ext_exists (v ".emacs.d") = true]}
    {- [ext_exists ~multi:true (v "a/f.gz") = false]}
    {- [ext_exists ~multi:true (v "a/f.tar.gz") = true]}
    {- [ext_exists ~multi:true (v ".emacs.d") = false]}}

    {2:ex_add_ext {!add_ext}}

    {ul
    {- [equal (add_ext ".mli" (v "a/b")) (v "a/b.mli")]}
    {- [equal (add_ext "mli" (v "a/b")) (v "a/b.mli")]}
    {- [equal (add_ext "." (v "a/b")) (v "a/b.")]}
    {- [equal (add_ext "" (v "a/b")) (v "a/b")]}
    {- [equal (add_ext ".tar.gz" (v "a/f")) (v "a/f.tar.gz")]}
    {- [equal (add_ext "tar.gz" (v "a/f")) (v "a/f.tar.gz")]}
    {- [equal (add_ext ".gz" (v "a/f.tar") ) (v "a/f.tar.gz")]}
    {- [equal (add_ext "gz" (v "a/f.tar") ) (v "a/f.tar.gz")]}}

    {2:ex_rem_ext {!rem_ext}}

    {ul
    {- [equal (rem_ext @@ v "/a/b") (v "/a/b")]}
    {- [equal (rem_ext @@ v "/a/b.mli") (v "/a/b")]}
    {- [equal (rem_ext @@ v "a/.ocamlinit") (v "a/.ocamlinit")]}
    {- [equal (rem_ext @@ v "f.tar.gz") (v "f.tar")]}
    {- [equal (rem_ext ~multi:true @@ v "f.tar.gz") (v "f")]}} *)

(*---------------------------------------------------------------------------
   Copyright 2014 Daniel C. Bünzli.
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   1. Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.

   3. Neither the name of Daniel C. Bünzli nor the names of
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  ---------------------------------------------------------------------------*)
