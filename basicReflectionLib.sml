structure basicReflectionLib = struct
local
  open HolKernel boolLib bossLib listSimps listSyntax pairSyntax stringSyntax
  open holSyntaxSyntax holSemanticsTheory holSemanticsExtraTheory holBoolTheory
in

datatype type_view = Tyvar of string | Tyapp of string * string * hol_type list

local open String in
fun tyvar_to_deep s =
  if sub(s,0) = #"'" then
    if size s = 2 then str(Char.toUpper (sub(s,1)))
    else extract(s,1,NONE)
  else s
end

fun type_view (ty : hol_type) =
  if is_type ty then
    case dest_thy_type ty of { Args = args, Thy = thy, Tyop = tyop } =>
      Tyapp (thy, tyop, args)
  else
    Tyvar (tyvar_to_deep (dest_vartype ty))

val string_to_inner = mlstringSyntax.mk_strlit o fromMLstring

fun type_to_deep ty = case type_view ty of
    Tyvar name => mk_Tyvar (string_to_inner (tyvar_to_deep name))
  | Tyapp (thy,name,args) =>
      mk_Tyapp(string_to_inner name, mk_list(List.map type_to_deep args, type_ty))

fun term_to_deep tm =
  case dest_term tm of
    VAR(x,ty) => mk_Var(string_to_inner x, type_to_deep ty)
  | CONST {Name,Thy,Ty} => mk_Const(string_to_inner Name, type_to_deep Ty)
  | COMB (f,x) => mk_Comb(term_to_deep f, term_to_deep x)
  | LAMB (x,b) =>
      let
        val (x,ty) = dest_var x
      in
        mk_Abs(mk_Var(string_to_inner x, type_to_deep ty), term_to_deep b)
      end

fun underscores [] = ""
  | underscores (x::xs) = "_" ^ x ^ underscores xs

fun type_name (ty : hol_type) = case type_view ty of
    Tyvar name            => tyvar_to_deep name
  | Tyapp (thy,tyop,args) => tyop ^ underscores (map type_name args)

val universe_ty = mk_vartype("'U")

val mem = ``mem:'U->'U->bool``
local
  open holSemanticsTheory
  fun genv x = (* genvar (type_of x) *)
    variant [] x
in
  val tysig = genv ``tysig:tysig``
  val tmsig = genv ``tmsig:tmsig``
  val tyass = genv ``tyass:'U tyass``
  val tmass = genv ``tmass:'U tmass``
  val tyval = genv ``tyval:'U tyval``
  val tmval = genv ``tmval:'U tmval``
end

val signatur = mk_pair(tysig,tmsig)
val interpretation = mk_pair(tyass,tmass)
val valuation = mk_pair(tyval,tmval)
val termsem_tm = ``termsem0 ^mem``
fun mk_termsem d =
  list_mk_comb(termsem_tm,[tmsig,interpretation,valuation,d])

val EVAL_STRING_SORT =
  CONV_TAC (DEPTH_CONV (fn tm => if can (match_term ``STRING_SORT (MAP explode (tyvars X))``) tm
                        then EVAL tm else raise UNCHANGED))

fun bool_interpretations interp_th =
  is_bool_interpretation_def
  |> SPECL [mem, rand(concl interp_th)]
  |> SIMP_RULE std_ss [interp_th,is_std_interpretation_def,GSYM CONJ_ASSOC]
  |> CONJUNCT2
  |> SIMP_RULE (std_ss++LIST_ss) [interprets_nil,interprets_one]

end
end
