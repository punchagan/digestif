module Bi = Rakia.Bi (* bigstring *)

(* This is from RFC 2022 (MD5/SHA1) and 4231 (SHA2) *)

let sp = Format.sprintf

let string_fold ~f ~z str =
  let st = ref z in
  ( String.iter (fun c -> st := f !st c) str  ; !st )

module type BIntf =
sig
  type t

  val set    : t -> int -> char -> unit
  val create : int -> t
  val sub    : t -> int -> int -> t
  val length : t -> int
  val equal : t -> t -> bool
  val pp : t Fmt.t
end

let hex (type buffer) (module B : BIntf with type t = buffer) str : buffer =
  let hexdigit = function
    | 'a' .. 'f' as x -> int_of_char x - 87
    | 'A' .. 'F' as x -> int_of_char x - 55
    | '0' .. '9' as x -> int_of_char x - 48
    | x               -> raise (Invalid_argument (sp "hex: `%c'" x))
  in
  let whitespace = function
    | ' ' | '\t' | '\r' | '\n' -> true
    | _                        -> false
  in
  match
    string_fold
    ~f:(fun (cs, i, acc) -> function
        | char when whitespace char -> (cs, i, acc)
        | char ->
            match (acc, hexdigit char) with
            | (None  , x) -> (cs, i, Some (x lsl 4))
            | (Some y, x) -> B.set cs i (Char.unsafe_chr (x lor y)) ; (cs, succ i, None))
    ~z:(B.create (String.length str), 0, None)
    str
  with
  | (_ , _, Some _) -> raise (Invalid_argument "hex: dangling nibble")
  | (cs, i, _     ) -> B.sub cs 0 i


let inputs (type buffer) (module B : BIntf with type t = buffer) : (buffer * buffer) list =
  let hex = hex (module B) in
  [
  (* Test Case 0 *)
  ( hex ("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b" ^
         "0b0b0b0b"),
    hex "4869205468657265" );                 (* "Hi There" *)
  (* Test Case 1 *)
  ( hex "4a656665",                           (* "Jefe" *)
    hex ("7768617420646f2079612077616e7420" ^ (* "what do ya want " *)
         "666f72206e6f7468696e673f") );       (* "for nothing?" *)
  (* Test Case 2 *)
  ( hex ("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaa"),
    hex ("dddddddddddddddddddddddddddddddd" ^
         "dddddddddddddddddddddddddddddddd" ^
         "dddddddddddddddddddddddddddddddd" ^
         "dddd") );
  (* Test Case 3 *)
  ( hex ("0102030405060708090a0b0c0d0e0f10" ^
         "111213141516171819"),
    hex ("cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd" ^
         "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd" ^
         "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd" ^
         "cdcd") );
  (* Test Case 4 *)
  ( hex ("0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c" ^
         "0c0c0c0c"),
    hex ("546573742057697468205472756e6361" ^ (* "Test With Trunca" *)
         "74696f6e") );                       (* "tion" *)
]

let sha2_inputs (type buffer) (module B : BIntf with type t = buffer) : (buffer * buffer) list =
  let hex = hex (module B) in
  inputs (module B) @ [
  (* Test Case 5 *)
  ( hex ("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaa"),
    hex ("54657374205573696e67204c61726765" ^ (* "Test Using Large" *)
         "72205468616e20426c6f636b2d53697a" ^ (* "r Than Block-Siz" *)
         "65204b6579202d2048617368204b6579" ^ (* "e Key - Hash Key" *)
         "204669727374") );                   (* " First" *)
  (* Test Case 6 *)
  ( hex ("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaa"),
    hex ("54686973206973206120746573742075" ^ (* "This is a test u" *)
         "73696e672061206c6172676572207468" ^ (* "sing a larger th" *)
         "616e20626c6f636b2d73697a65206b65" ^ (* "an block-size ke" *)
         "7920616e642061206c61726765722074" ^ (* "y and a larger t" *)
         "68616e20626c6f636b2d73697a652064" ^ (* "han block-size d" *)
         "6174612e20546865206b6579206e6565" ^ (* "ata. The key nee" *)
         "647320746f2062652068617368656420" ^ (* "ds to be hashed " *)
         "6265666f7265206265696e6720757365" ^ (* "before being use" *)
         "642062792074686520484d414320616c" ^ (* "d by the HMAC al" *)
         "676f726974686d2e") )]               (* "gorithm." *)

let sha1_inputs (type buffer) (module B : BIntf with type t = buffer) : (buffer * buffer) list =
  let hex = hex (module B) in
  inputs (module B) @ [
  (* Test Case 5 *)
  ( hex ("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
    hex ("54657374205573696e67204c61726765" ^ (* "Test Using Large" *)
         "72205468616e20426c6f636b2d53697a" ^ (* "r Than Block-Siz" *)
         "65204b6579202d2048617368204b6579" ^ (* "e Key - Hash Key" *)
         "204669727374") );                   (* " First" *)
  (* Test Case 6 *)
  ( hex ("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ^
         "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
    hex ("54657374205573696e67204c61726765" ^ (* "Test Using Large" *)
         "72205468616e20426c6f636b2d53697a" ^ (* "r Than Block-Siz" *)
         "65204b657920616e64204c6172676572" ^ (* "e Key and Larger" *)
         "205468616e204f6e6520426c6f636b2d" ^ (* " Than One Block-" *)
         "53697a652044617461") )]             (* "Size Data" *)

let md5_inputs (type buffer) (module B : BIntf with type t = buffer) : (buffer * buffer) list =
  let k, d = List.split (sha1_inputs (module B)) in
  let keys =
    List.mapi (fun i x ->
      if i == 3 || i == 5 || i == 6 then
        x
      else B.(sub x 0 (min (length x) 16)))
    k in
  List.combine keys d

let blake2b_inputs (type buffer) (module B : BIntf with type t = buffer) : (buffer * buffer) list =
  let k, d = List.split (sha1_inputs (module B)) in
  let keys =
    List.mapi (fun i x -> B.(sub x 0 (min (length x) 64)))
    k in
  List.combine keys d

let md5_results (type buffer) (module B : BIntf with type t = buffer) : buffer list =
  let hex = hex (module B) in
  [ hex "9294727a3638bb1c13f48ef8158bfc9d"
  ; hex "750c783e6ab0b503eaa86e310a5db738"
  ; hex "56be34521d144c88dbb8c733f0e8b3f6"
  ; hex "697eaf0aca3a3aea3a75164746ffaa79"
  ; hex "56461ef2342edc00f9bab995"
  ; hex "6b1ab7fe4bd7bf8f0b62e6ce61b9d0cd"
  ; hex "6f630fad67cda0ee1fb1f562db3aa53e" ]

let sha1_results  (type buffer) (module B : BIntf with type t = buffer) : buffer list =
  let hex = hex (module B) in
  [ hex "b617318655057264e28bc0b6fb378c8ef146be00"
  ; hex "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79"
  ; hex "125d7342b9ac11cd91a39af48aa17b4f63f175d3"
  ; hex "4c9007f4026250c6bc8414f9bf50c86c2d7235da"
  ; hex "4c1a03424b55e07fe7f27be1"
  ; hex "aa4ae5e15272d00e95705637ce8a3b55ed402112"
  ; hex "e8e99d0f45237d786d6bbaa7965c7808bbff1a91" ]

let sha224_results (type buffer) (module B : BIntf with type t = buffer) : buffer list =
  let hex = hex (module B) in
  [ hex "896fb1128abbdf196832107cd49df33f\
         47b4b1169912ba4f53684b22"
  ; hex "a30e01098bc6dbbf45690f3a7e9e6d0f\
         8bbea2a39e6148008fd05e44"
  ; hex "7fb3cb3588c6c1f6ffa9694d7d6ad264\
         9365b0c1f65d69d1ec8333ea"
  ; hex "6c11506874013cac6a2abc1bb382627c\
         ec6a90d86efc012de7afec5a"
  ; hex "0e2aea68a90c8d37c988bcdb9fca6fa8"
  ; hex "95e9a0db962095adaebe9b2d6f0dbce2\
         d499f112f2d2b7273fa6870e"
  ; hex "3a854166ac5d9f023f54d517d0b39dbd\
         946770db9c2b95c9f6f565d1" ]

let sha256_results  (type buffer) (module B : BIntf with type t = buffer) : buffer list =
  let hex = hex (module B) in
  [ hex "b0344c61d8db38535ca8afceaf0bf12b\
         881dc200c9833da726e9376c2e32cff7"
  ; hex "5bdcc146bf60754e6a042426089575c7\
         5a003f089d2739839dec58b964ec3843"
  ; hex "773ea91e36800e46854db8ebd09181a7\
         2959098b3ef8c122d9635514ced565fe"
  ; hex "82558a389a443c0ea4cc819899f2083a\
         85f0faa3e578f8077a2e3ff46729665b"
  ; hex "a3b6167473100ee06e0c796c2955552b"
  ; hex "60e431591ee0b67f0d8a26aacbf5b77f\
         8e0bc6213728c5140546040f0ee37f54"
  ; hex "9b09ffa71b942fcb27635fbcd5b0e944\
         bfdc63644f0713938a7f51535c3a35e2" ]

let sha384_results (type buffer) (module B : BIntf with type t = buffer) : buffer list =
  let hex = hex (module B) in
  [ hex "afd03944d84895626b0825f4ab46907f\
         15f9dadbe4101ec682aa034c7cebc59c\
         faea9ea9076ede7f4af152e8b2fa9cb6"
  ; hex "af45d2e376484031617f78d2b58a6b1b\
         9c7ef464f5a01b47e42ec3736322445e\
         8e2240ca5e69e2c78b3239ecfab21649"
  ; hex "88062608d3e6ad8a0aa2ace014c8a86f\
         0aa635d947ac9febe83ef4e55966144b\
         2a5ab39dc13814b94e3ab6e101a34f27"
  ; hex "3e8a69b7783c25851933ab6290af6ca7\
         7a9981480850009cc5577c6e1f573b4e\
         6801dd23c4a7d679ccf8a386c674cffb"
  ; hex "3abf34c3503b2a23a46efc619baef897"
  ; hex "4ece084485813e9088d2c63a041bc5b4\
         4f9ef1012a2b588f3cd11f05033ac4c6\
         0c2ef6ab4030fe8296248df163f44952"
  ; hex "6617178e941f020d351e2f254e8fd32c\
         602420feb0b8fb9adccebb82461e99c5\
         a678cc31e799176d3860e6110c46523e" ]

let sha512_results (type buffer) (module B : BIntf with type t = buffer) : buffer list =
  let hex = hex (module B) in
  [ hex "87aa7cdea5ef619d4ff0b4241a1d6cb0\
         2379f4e2ce4ec2787ad0b30545e17cde\
         daa833b7d6b8a702038b274eaea3f4e4\
         be9d914eeb61f1702e696c203a126854"
  ; hex "164b7a7bfcf819e2e395fbe73b56e0a3\
         87bd64222e831fd610270cd7ea250554\
         9758bf75c05a994a6d034f65f8f0e6fd\
         caeab1a34d4a6b4b636e070a38bce737"
  ; hex "fa73b0089d56a284efb0f0756c890be9\
         b1b5dbdd8ee81a3655f83e33b2279d39\
         bf3e848279a722c806b485a47e67c807\
         b946a337bee8942674278859e13292fb"
  ; hex "b0ba465637458c6990e5a8c5f61d4af7\
         e576d97ff94b872de76f8050361ee3db\
         a91ca5c11aa25eb4d679275cc5788063\
         a5f19741120c4f2de2adebeb10a298dd"
  ; hex "415fad6271580a531d4179bc891d87a6"
  ; hex "80b24263c7c1a3ebb71493c1dd7be8b4\
         9b46d1f41b4aeec1121b013783f8f352\
         6b56d037e05f2598bd0fd2215d6a1e52\
         95e64f73f63f0aec8b915a985d786598"
  ; hex "e37b6a775dc87dbaa4dfa9f96e5e3ffd\
         debd71f8867289865df5a32d20cdc944\
         b6022cac3c4982b10d5eeb55c3e4de15\
         134676fb6de0446065c97440fa8c6a58" ]

let blake2b_results (type buffer) (module B : BIntf with type t = buffer) : buffer list =
  let hex = hex (module B) in
  [ hex "35e968d3b8ea56fa47e9d929f1f1b523\
         ae90fe7fe0462b3caf2e45648043f7c5\
         a3009e942a8c8690ce192baf408ab0c1\
         4659a9ba983e9049c18f4efe74b7e4df"
  ; hex "380246f80263db862b00d41ebb70e6d2\
         6fa97c4b42ae7985991deb963b4317aa\
         33735ff9dc76bd294455731365ab3a9e\
         b67d33f83f98360f2bae5f7a4356e6b1"
  ; hex "479af3a24a9a7b9aa12379ff608c6594\
         add1f08173939a9aa53599820dde14f3\
         a781bc0dbc0ca30cfda5da2e3b611717\
         395b5488ad4425b8519fa8b8a38518c4"
  ; hex "78a4f03179636fb7bf37f908def45746\
         481df654263f46a6ff7580d3194522c6\
         59d9fa1c4b1ce2dd7e115c49c4f8500b\
         178cc32e79804bdaef3c18f696e5c6a0"
  ; hex "b9c15344efb9efc8f1b7cc277c9c31d8\
         1164461af1b06c1db059617f133dbe76\
         e3d55870c78fb762de9480d17668f6c5\
         6a8d9620218074a61ca852865b4cfc00"
  ; hex "86ba79afb89ddc1e3a480684fd1e750d\
         5a58a9631b5f7ec5aa6a7962d59a909f\
         bf506e5add0933ab3630e2fdc63bc742\
         e14f55ce46bcc1b7ece869599d53107c"
  ; hex "7f43946d568adcc15f411a697d6776f5\
         37f9b27cb475c8bc110054fd06d16782\
         8aa9861cea094a6498837ddbd05ef3b0\
         9b01fa2130d618d09105b2c680bff556" ]

module TestBigstring : Alcotest.TESTABLE with type t = Bi.t =
struct
  type t = Bi.t

  let equal = Bi.equal

  let pp fmt hash =
    for i = 0 to Bi.length hash - 1
    do Format.fprintf fmt "%02x" (Char.code @@ Bi.get hash i) done
end

let testable (type a) (pp : a Fmt.t) (equal : a -> a -> bool) : a Alcotest.testable =
  let module M = struct type t = a let pp = pp let equal = equal end in
  (module M)

let test_hmac (type buffer)
    (module B : BIntf with type t = buffer)
    (hmac : Rakia.hash -> key:buffer -> buffer -> buffer)
    (hash : Rakia.hash)
    idx
    (((key, data), result) : ((buffer * buffer) * buffer)) =
  let computed = hmac hash ~key:key data in
  Alcotest.(check (testable B.pp B.equal)) "hmac" result (if idx == 4 then B.(sub computed 0 (length result)) else computed)

type 'a buffer =
  | Bytes     : (module BIntf with type t = Bytes.t) -> Bytes.t buffer
  | Bigstring : (module BIntf with type t = Bi.t) -> Bi.t buffer

let make_test_hmac (type a) name hash (buffer : a buffer)
  : ((module BIntf with type t = a) -> (a * a) list)
    -> ((module BIntf with type t = a) -> a list)
    -> Alcotest.test_case list
  = match buffer with
  | Bytes (module B : BIntf with type t = Bytes.t) ->
    fun inputs results ->
      let hmac = Rakia.Bytes.mac in
      let inputs = inputs (module B : BIntf with type t = Bytes.t) in
      let results = results (module B : BIntf with type t = Bytes.t) in
      List.mapi
        (fun i args ->
           let title = name ^ " " ^ string_of_int i in
           title,
           `Slow,
           (fun () -> test_hmac (module B) hmac hash i args))
        (List.combine inputs results)
  | Bigstring (module B : BIntf with type t = Bi.t) ->
    fun inputs results ->
      let hmac = Rakia.Bigstring.mac in
      let inputs = inputs (module B : BIntf with type t = Bi.t) in
      let results = results (module B : BIntf with type t = Bi.t) in
      List.mapi
        (fun i args ->
           let title = name ^ " " ^ string_of_int i in
           title,
           `Slow,
           (fun () -> test_hmac (module B) hmac hash i args))
        (List.combine inputs results)

module Bytes =
struct
  include Bytes

  let pp fmt by =
    for i = 0 to length by
    do Format.fprintf fmt "%c" (get by i) done
end

let () =
  let bi = Bigstring (module Bi) in
  let by = Bytes (module Bytes) in

  Alcotest.run "Rakia"
    [ "MD5 (Bigstring)",     make_test_hmac "MD5"     `MD5     bi md5_inputs md5_results
    ; "MD5 (Bytes)",         make_test_hmac "MD5"     `MD5     by md5_inputs md5_results
    ; "SHA1 (Bigstring)",    make_test_hmac "SHA1"    `SHA1    bi sha1_inputs sha1_results
    ; "SHA1 (Bytes)",        make_test_hmac "SHA1"    `SHA1    by sha1_inputs sha1_results
    ; "SHA224 (Bigstring)",  make_test_hmac "SHA224"  `SHA224  bi sha2_inputs sha224_results
    ; "SHA224 (Bytes)",      make_test_hmac "SHA224"  `SHA224  by sha2_inputs sha224_results
    ; "SHA256 (Bigstring)",  make_test_hmac "SHA256"  `SHA256  bi sha2_inputs sha256_results
    ; "SHA256 (Byes)",       make_test_hmac "SHA256"  `SHA256  by sha2_inputs sha256_results
    ; "SHA384 (Bigstring)",  make_test_hmac "SHA384"  `SHA384  bi sha2_inputs sha384_results
    ; "SHA384 (Bytes)",      make_test_hmac "SHA384"  `SHA384  by sha2_inputs sha384_results
    ; "SHA512 (Bigstring)",  make_test_hmac "SHA512"  `SHA512  bi sha2_inputs sha512_results
    ; "SHA512 (Bytes)",      make_test_hmac "SHA512"  `SHA512  by sha2_inputs sha512_results
    ; "BLAKE2B (Bigstring)", make_test_hmac "BLAKE2B" `BLAKE2B bi blake2b_inputs blake2b_results
    ; "BLAKE2B (Bytes)",     make_test_hmac "BLAKE2B" `BLAKE2B by blake2b_inputs blake2b_results ]

