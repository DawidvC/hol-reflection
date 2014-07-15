open HolKernel boolLib bossLib lcsymtacs
open miscLib pairSyntax stringSyntax listSyntax holSyntaxSyntax
open reflectionTheory pred_setTheory setSpecTheory holSyntaxTheory holSemanticsTheory holSemanticsExtraTheory

val _ = temp_tight_equality()
val _ = new_theory"sketch"

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

fun type_to_deep ty = case type_view ty of
    Tyvar name => mk_Tyvar (fromMLstring name)
  | Tyapp (thy,name,args) =>
      mk_Tyapp(fromMLstring name, mk_list(List.map type_to_deep args, type_ty))

fun term_to_deep tm =
  case dest_term tm of
    VAR(x,ty) => mk_Var(fromMLstring x, type_to_deep ty)
  | CONST {Name,Thy,Ty} => mk_Const(fromMLstring Name, type_to_deep Ty)
  | COMB (f,x) => mk_Comb(term_to_deep f, term_to_deep x)
  | LAMB (x,b) =>
      let
        val (x,ty) = dest_var x
      in
        mk_Abs(fromMLstring x, type_to_deep ty, term_to_deep b)
      end

fun underscores [] = ""
  | underscores (x::xs) = "_" ^ x ^ underscores xs

fun type_name (ty : hol_type) = case type_view ty of
    Tyvar name            => tyvar_to_deep name
  | Tyapp (thy,tyop,args) => tyop ^ underscores (map type_name args)

val U = mk_vartype("'U")
fun mk_in_var (ty : hol_type) =
  mk_var ("in_" ^ type_name ty, ty --> U)

val in_bool_tm = ``in_bool``
val in_fun_tm = ``in_fun``

fun mk_in (ty : hol_type) = case type_view ty of
    Tyapp(thy, "bool", [])        => in_bool_tm
  | Tyapp(thy, "fun",  [ty1,ty2]) => mk_binop in_fun_tm (mk_in ty1, mk_in ty2)
  | _                             => mk_in_var ty

fun genv x =
  (*
  let
    val (name,ty) = dest_var x in
  in
    genvar ty
  end
  *)
  variant [] x

val mem = ``mem:'U->'U->bool``
val tysig = genv ``tysig:tyenv``
val tmsig = genv ``tmsig:tmenv``
val tyass = genv ``tyass:'U tyass``
val tmass = genv ``tmass:'U tmass``
val tyval = genv ``tyval:'U tyval``
val tmval = genv ``tmval:'U tmval``
val signatur = mk_pair(tysig,tmsig)
val interpretation = mk_pair(tyass,tmass)
val valuation = mk_pair(tyval,tmval)
val termsem_tm = ``termsem0 ^mem``
fun mk_termsem d =
  list_mk_comb(termsem_tm,[tmsig,interpretation,valuation,d])

val good_context_def = Define`
  good_context ^mem ^tysig ^tmsig ^tyass ^tmass ^tyval ^tmval ⇔
    is_set_theory ^mem ∧
    is_std_sig ^signatur ∧
    is_interpretation ^signatur ^interpretation ∧
    is_std_interpretation ^interpretation ∧
    is_valuation ^tysig ^tyass ^valuation`
val good_context = good_context_def |> concl |> strip_forall |> snd |> lhs

val Var_thm = prove(
  ``^tmval (x,ty) = inty v ⇒
    ∀mem. inty v = termsem0 mem ^tmsig ^interpretation ^valuation (Var x ty)``,
  rw[termsem_def])

val Const_thm = prove(
  ``instance ^tmsig ^interpretation name ty ^tyval = inty c ⇒
    ∀mem. inty c = termsem0 mem ^tmsig ^interpretation ^valuation (Const name ty)``,
  rw[termsem_def])

val instance_tm = Term.inst[alpha|->``:'U``]``instance``
fun mk_instance name ty =
  list_mk_comb(instance_tm,[tmsig,interpretation,name,ty,tyval])

val Comb_thm = prove(
  ``^good_context ⇒
    in_fun ina inb f = termsem ^tmsig ^interpretation ^valuation ftm ∧
    ina x = termsem ^tmsig ^interpretation ^valuation xtm ⇒
    is_in ina ⇒ is_in inb
    ⇒
    inb (f x) =
      termsem ^tmsig ^interpretation ^valuation (Comb ftm xtm)``,
  rw[good_context_def,termsem_def] >>
  rpt(first_x_assum(SUBST1_TAC o SYM)) >>
  rw[in_fun_def] >>
  match_mp_tac EQ_SYM >>
  match_mp_tac apply_abstract_matchable >>
  simp[] >>
  rw[is_in_range_thm] >>
  AP_TERM_TAC >>
  AP_TERM_TAC >>
  match_mp_tac is_in_finv_left >>
  simp[]) |> UNDISCH

val Abs_thm = prove(
  ``^good_context ⇒
    ∀ina inb f x ty b.
    range ina = typesem tyass tyval ty ⇒
    range inb = typesem tyass tyval (typeof b) ⇒
    is_in ina ⇒ is_in inb ⇒
    (∀m. m <: range ina ⇒
      inb (f (finv ina m)) =
        termsem tmsig (tyass,tmass) (tyval,((x,ty) =+ m) tmval) b) ⇒
    term_ok (tysig,tmsig) b
    ⇒
    in_fun ina inb f =
      termsem tmsig (tyass,tmass) (tyval,tmval) (Abs x ty b)``,
  rw[termsem_def,in_fun_def,good_context_def] >>
  match_mp_tac (UNDISCH abstract_eq) >> simp[] >>
  rw[] >>
  match_mp_tac (UNDISCH termsem_typesem) >>
  simp[] >>
  qexists_tac`(tysig,tmsig)` >> simp[] >>
  fs[is_std_interpretation_def] >>
  fs[is_valuation_def,is_term_valuation_def] >>
  simp[combinTheory.APPLY_UPDATE_THM] >>
  rw[] >> metis_tac[]) |> UNDISCH

fun var_to_cert v =
  let
    val v_deep = term_to_deep (assert is_var v)
    val (x_deep,ty_deep) = dest_Var v_deep
    val l = mk_comb(mk_in (type_of v),v)
    val a = mk_eq(mk_comb(tmval,mk_pair(x_deep,ty_deep)),l)
  in
    MATCH_MP Var_thm (ASSUME a) |> SPEC mem
  end

fun const_to_cert c =
  let
    val c_deep = term_to_deep (assert is_const c)
    val (name_deep,ty_deep) = dest_Const c_deep
    val l = mk_comb(mk_in (type_of c),c)
    val a = mk_eq(mk_instance name_deep ty_deep,l)
  in
    MATCH_MP Const_thm (ASSUME a) |> SPEC mem
  end

val good_context_is_in_in_bool = prove(mk_imp(good_context,rand(concl(is_in_in_bool))),
  rw[good_context_def,is_in_in_bool]) |> UNDISCH
val good_context_is_in_in_fun = prove(mk_imp(good_context,rand(concl(is_in_in_fun))),
  rw[good_context_def,is_in_in_fun]) |> UNDISCH
val good_context_lookup_bool = prove(
  ``^good_context ⇒ FLOOKUP ^tysig "bool" = SOME 0``,
  rw[good_context_def,is_std_sig_def]) |> UNDISCH
val good_context_lookup_fun = prove(
  ``^good_context ⇒ FLOOKUP ^tysig "fun" = SOME 2``,
  rw[good_context_def,is_std_sig_def]) |> UNDISCH

val good_context_extend_tmval = prove(
  ``^good_context ∧
     m <: typesem ^tyass ^tyval ty ⇒
     good_context ^mem ^tysig ^tmsig ^tyass ^tmass ^tyval (((x,ty) =+ m) ^tmval)``,
  rw[good_context_def,is_valuation_def,is_term_valuation_def,combinTheory.APPLY_UPDATE_THM] >>
  rw[] >> rw[])

val EVAL_STRING_SORT =
  CONV_TAC (DEPTH_CONV (fn tm => if can (match_term ``STRING_SORT (tyvars X)``) tm
                        then EVAL tm else raise UNCHANGED))

val good_context_instance_equality = prove(
  ``∀ty ina.
    ^good_context ∧
    type_ok ^tysig ty ∧
    typesem ^tyass ^tyval ty = range (in_fun ina in_bool) ∧
    is_in ina ⇒
    instance ^tmsig ^interpretation "=" (Fun ty (Fun ty Bool)) ^tyval =
      in_fun (in_fun ina in_bool) (in_fun (in_fun ina in_bool) in_bool) $=``,
  rw[good_context_def] >>
  fs[is_std_sig_def] >>
  imp_res_tac instance_def >>
  first_x_assum(qspec_then`[ty,Tyvar "A"]`mp_tac) >>
  simp[holSyntaxLibTheory.REV_ASSOCD] >>
  disch_then(mp_tac o SPEC interpretation) >>
  simp[] >> disch_then kall_tac >>
  EVAL_STRING_SORT >> simp[holSyntaxLibTheory.REV_ASSOCD] >>
  fs[is_std_interpretation_def,interprets_def] >>
  first_x_assum(qspec_then`("A"=+ typesem ^tyass ^tyval ty)(K boolset)`mp_tac) >>
  discharge_hyps >- (
    simp[is_type_valuation_def,combinTheory.APPLY_UPDATE_THM] >>
    reverse(rw[mem_boolset]) >- metis_tac[] >>
    qpat_assum`X = Y` (SUBST1_TAC o SYM) >>
    match_mp_tac (UNDISCH typesem_inhabited) >>
    fs[is_valuation_def,is_interpretation_def] >>
    metis_tac[] ) >>
  simp[combinTheory.APPLY_UPDATE_THM] >>
  disch_then kall_tac >>
  simp[in_fun_def] >>
  match_mp_tac (UNDISCH abstract_eq) >>
  simp[] >> gen_tac >> strip_tac >>
  conj_tac >- (
    match_mp_tac (UNDISCH abstract_in_funspace) >>
    simp[boolean_in_boolset] ) >>
  Q.ISPECL_THEN[`mem`,`in_bool`,`ina`]mp_tac (GEN_ALL range_in_fun) >>
  discharge_hyps >- ( simp[is_in_in_bool] ) >>
  strip_tac >> simp[range_in_bool] >>
  Q.ISPECL_THEN[`mem`,`in_bool`,`in_fun ina in_bool`]mp_tac (GEN_ALL range_in_fun) >>
  discharge_hyps >- ( simp[is_in_in_bool,is_in_in_fun] ) >>
  strip_tac >> simp[range_in_bool] >>
  conj_tac >- (
    match_mp_tac (UNDISCH abstract_in_funspace) >>
    simp[in_bool_def,boolean_in_boolset] ) >>
  match_mp_tac (UNDISCH abstract_eq) >>
  simp[in_bool_def,boolean_in_boolset] >>
  simp[boolean_def] >> rw[true_neq_false] >>
  spose_not_then strip_assume_tac >>
  qpat_assum`X = Y`mp_tac >> simp[] >>
  qmatch_assum_rename_tac`z <: Funspace X boolset`["X"] >>
  qspecl_then[`z`,`range ina`,`boolset`]mp_tac (UNDISCH in_funspace_abstract) >>
  discharge_hyps >- (
    simp[mem_boolset] >>
    imp_res_tac is_in_range_thm >>
    metis_tac[] ) >>
  rw[] >> fs[] >>
  qspecl_then[`x`,`range ina`,`boolset`]mp_tac (UNDISCH in_funspace_abstract) >>
  discharge_hyps >- (
    simp[mem_boolset] >>
    imp_res_tac is_in_range_thm >>
    rfs[range_in_bool] >>
    metis_tac[] ) >>
  rw[] >> fs[] >>
  qmatch_assum_abbrev_tac`Abstract a b f1 ≠ Abstract a b f2` >>
  `(∃x. Abstract a b f1 = in_fun ina Boolean x) ∧
   (∃x. Abstract a b f2 = in_fun ina Boolean x)` by (
    conj_tac >>
    simp[in_fun_def,GSYM in_bool_def,range_in_bool] >|[
      qexists_tac`finv Boolean o f1 o ina`,
      qexists_tac`finv Boolean o f2 o ina`] >>
    match_mp_tac (UNDISCH abstract_eq) >>
    simp[in_bool_def,Abbr`b`,boolean_in_boolset] >>
    simp[Abbr`a`] >> rw[] >>
    imp_res_tac is_in_finv_right >>
    pop_assum (SUBST1_TAC) >>
    match_mp_tac EQ_SYM >>
    match_mp_tac (MP_CANON is_in_finv_right) >>
    simp[GSYM in_bool_def,range_in_bool,is_in_in_bool] ) >>
  rw[] >>
  metis_tac[is_in_finv_left,is_in_in_fun,is_in_in_bool,in_bool_def])

fun NCONV 0 c = ALL_CONV
  | NCONV n c = c THENC (NCONV (n-1) c)

fun n_imp_and_intro 0 = ALL_CONV
  | n_imp_and_intro n = REWR_CONV (GSYM AND_IMP_INTRO) THENC
                       (RAND_CONV (n_imp_and_intro (n-1)))

(* given [...,A,...] |- P and H |- A <=> B1 /\ ... /\ Bn
   produce [...,B1,...,Bn,...] ∪ H |- P *)
fun simplify_assum th simpth =
  let
    val A = lhs(concl simpth)
    val th1 = DISCH A th
    val th2 = CONV_RULE(LAND_CONV(REWR_CONV simpth)) th1
    val n = length(strip_conj(rhs(concl simpth)))
    val th3 = CONV_RULE (n_imp_and_intro (n-1)) th2
  in
    funpow n UNDISCH th3
  end

(* given [...,A',...] |- P and H |- !x1..xn. B1 /\ ... /\ Bn ==> A
   produce [...,B1',...,Bn',...] ∪ H |- P *)
fun replace_assum th simpth =
  let
    val c = simpth |> concl
    val (xs,b) = c |> strip_forall
    val A = b |> rand
    val A' = first (can (match_term A)) (hyp th)
    val th1 = DISCH A' th
    val (s,_) = match_term A A'
    val th2 = ISPECL (map (fn x => #residue(first (equal (fst(dest_var x)) o fst o dest_var o #redex) s)) xs) simpth
    val n = b |> dest_imp |> fst |> strip_conj |> length
    val th3 = CONV_RULE (n_imp_and_intro (n-1)) th2
    val th4 = funpow n UNDISCH th3
  in
    MP th1 th4
  end

fun term_to_cert tm =
  case dest_term tm of
    VAR _ => var_to_cert tm
  | CONST _ => const_to_cert tm
  | COMB(t1,t2) =>
    let
      val c1 = term_to_cert t1
      val c2 = term_to_cert t2
    in
      MATCH_MP (Comb_thm) (CONJ c1 c2)
      |> UNDISCH |> UNDISCH
      |> PROVE_HYP good_context_is_in_in_bool
    end
  | LAMB(x,b) =>
    let
      val (xd,tyd) = dest_Var(term_to_deep x)
      val bd = term_to_deep b
      val cx = var_to_cert x
      val cb = term_to_cert b
      val ina = cx |> concl |> lhs |> rator
      val inb = cb |> concl |> lhs |> rator
      val th = Abs_thm |> ISPECL[ina,inb,tm,xd,tyd,bd] |> funpow 4 UNDISCH
      val goal = (mk_set(hyp cb @ hyp th), th |> concl |> dest_imp |> fst)
      val th1 = TAC_PROOF(goal,
        rw[] >>
        match_mp_tac (MP_CANON (DISCH_ALL cb)) >>
        simp[combinTheory.APPLY_UPDATE_THM] >>
        TRY (
        conj_tac >- (
          match_mp_tac good_context_extend_tmval >>
          rw[] ) >>
        metis_tac[is_in_finv_right] ))
      val th2 = MP th th1
    in
      UNDISCH th2
    end

val MID_EXISTS_AND_THM = prove(
  ``(?x. P x /\ Q /\ R x) <=> (Q /\ ?x. P x /\ R x)``,
  metis_tac[])

val test_tm = ``λg. g (f T)``
val test_tm = ``g = (λx. F)``
val test = term_to_cert test_tm
(*
val cs = listLib.list_compset()
val () = computeLib.add_thms [typeof_def,codomain_def,typesem_def] cs
val eval = computeLib.CBV_CONV cs
*)
val eval = SIMP_CONV (std_ss++listSimps.LIST_ss)
  [typeof_def,codomain_def,typesem_def,
   term_ok_def,holSyntaxExtraTheory.WELLTYPED_CLAUSES,
   type_ok_def,type_11]
 THENC SIMP_CONV std_ss [GSYM CONJ_ASSOC,MID_EXISTS_AND_THM]

val simpths = mapfilter
  (QCHANGED_CONV eval)
  (hyp test)
(*
val test1 = simplify_assum test (hd simpths)
val test2 = simplify_assum test1 (hd (tl simpths))
val test3 = simplify_assum test2 (hd (tl (tl simpths)))
*)
val test1 = foldl (uncurry (C simplify_assum)) test simpths
val test2 = repeat (fn th => replace_assum th good_context_is_in_in_fun) test1
val test3 = PROVE_HYP good_context_is_in_in_bool test2
val test4 = PROVE_HYP good_context_lookup_bool test3
val test5 = replace_assum test4 good_context_instance_equality
val simpths = mapfilter
  (QCHANGED_CONV eval)
  (hyp test5)
val test6 = foldl (uncurry (C simplify_assum)) test5 simpths
val test7 = PROVE_HYP good_context_lookup_bool test6
val test8 = PROVE_HYP good_context_lookup_fun test7


(*
val tm = ``λx:bool. f x``
term_to_cert tm
*)

(*
val it = set_goal goal
show_assums := true
*)

val base_tysig_def = Define`
  base_tysig = FEMPTY |++ [("fun",2);("bool",0)]`
val base_tmsig_def = Define`
  base_tmsig = FEMPTY |++ [("=",Fun (Tyvar "A") (Tyvar "A"))]`

(*
val P = ``x:bool``
val tysig = ``base_tysig``
val tmsig = ``base_tmsig``
val thm = prove(
  ``is_set_theory ^mem ∧
    is_interpretation (^tysig,^tmsig) (tyass,tmass) ∧
    is_std_interpretation (tyass,tmass) ∧
    is_valuation ^tysig tmass (tyval,tmval) ∧
    tmval ("x",Bool) = in_bool x
    ⇒
    in_bool x =
      termsem ^tmsig (tyass,tmass) (tyval,tmval) (Var "x" Bool)``,
  rw[termsem_def])


val P = ``(f:bool->bool) x``
val tysig = ``base_tysig``
val tmsig = ``base_tmsig``

val P = ``λ(x:bool). x``
val tysig = ``base_tysig``
val tmsig = ``base_tmsig``
val Abs_thm = store_thm("Abs_thm",
  ``is_set_theory ^mem ∧
    is_interpretation (^tysig,^tmsig) (tyass,tmass) ∧
    is_std_interpretation (tyass,tmass) ∧
    is_valuation ^tysig tmass (tyval,tmval)
    ⇒
    in_fun in_bool in_bool ^P =
      termsem ^tmsig (tyass,tmass) (tyval,tmval) (^(term_to_deep P))``,
  rw[termsem_def,in_fun_def] >>
  rw[typesem_def] >>
  `tyass "bool" [] = boolset` by (
    fs[is_std_interpretation_def,is_std_type_assignment_def] )>>
  `range in_bool = boolset` by (
    imp_res_tac is_in_in_bool >>
    imp_res_tac is_in_bij_thm >>
    imp_res_tac is_extensional >>
    fs[extensional_def] >>
    pop_assum kall_tac >>
    simp[mem_boolset] >>
    fs[BIJ_IFF_INV,ext_def,in_bool_def,boolean_def] >>
    metis_tac[] ) >>
  simp[] >>
  match_mp_tac (UNDISCH abstract_eq) >>
  simp[combinTheory.APPLY_UPDATE_THM] >>
  imp_res_tac is_in_in_bool >>
  imp_res_tac is_in_bij_thm >>
  rfs[ext_def,BIJ_DEF,INJ_DEF] >>
  metis_tac[is_in_finv_right,is_in_in_bool])

rw[typesem_def] >>
`tyass "bool" [] = boolset` by (
  fs[is_std_interpretation_def,is_std_type_assignment_def] )>>

`range in_bool = boolset` by (
  imp_res_tac is_in_in_bool >>
  imp_res_tac is_in_bij_thm >>
  imp_res_tac is_extensional >>
  fs[extensional_def] >>
  pop_assum kall_tac >>
  simp[mem_boolset] >>
  fs[BIJ_IFF_INV,ext_def,in_bool_def,boolean_def] >>
  metis_tac[] ) >>
simp[] >>
match_mp_tac (UNDISCH abstract_eq) >>
simp[combinTheory.APPLY_UPDATE_THM] >>
imp_res_tac is_in_in_bool >>
imp_res_tac is_in_bij_thm >>
rfs[ext_def,BIJ_DEF,INJ_DEF] >>
metis_tac[is_in_finv_right,is_in_in_bool])
*)

(*
P = ``ARB (c:α->β) (x:ind->ind) (ARB:α list)``
P_deep = ``Comb (Const ...) ...``
*)
val c_def = Define`c : γ = ARB`

val tysig = ``FEMPTY |++ [("list",1);("ind",0)]``
val tmsig = ``FEMPTY |+ ("c",(Tyvar "'c"))``
val P_deep = ``ARB:term``

val example =
  ``is_set_theory ^mem ∧
    BIJ (in_α : α -> 'U) UNIV (ext (tyval "'a")) ∧
    BIJ (in_β : β -> 'U) UNIV (ext (tyval "'b")) ∧
    BIJ (in_ind : ind -> 'U) UNIV (ext (tyass "ind" [])) ∧
    BIJ (in_list_α : α list -> 'U) UNIV (ext (tyass "list" [tyval "'a"])) ∧
    is_interpretation (^tysig,^tmsig) (tyass,tmass) ∧
    is_std_interpretation (tyass,tmass) ∧
    tmass "c" [range (in_fun in_α in_β)] = in_fun in_α in_β c ∧
    is_valuation ^tysig tmass (tyval,tmval) ∧
    tmval ("x",Fun Ind Ind) = in_fun in_ind in_ind x
    ⇒
    in_fun in_α (in_fun in_β in_ind) P =
       termsem ^tmsig (tyass,tmass) (tyval,tmval) ^P_deep``

val example_sequent =
  ( [ ``is_set_theory ^mem``
    , ``is_interpretation (^tysig,^tmsig) (tyass,tmass)``
    , ``is_std_interpretation (tyass,tmass)``
    , ``is_valuation ^tysig tmass (tyval,tmval)``
    , ``BIJ (in_α : α -> 'U) UNIV (ext (tyval "'a"))``
    , ``BIJ (in_β : β -> 'U) UNIV (ext (tyval "'b"))``
    , ``BIJ (in_ind : ind -> 'U) UNIV (ext (tyass "ind" []))``
    , ``BIJ (in_list_α : α list -> 'U) UNIV (ext (tyass "list" [tyval "'a"]))``
    , ``tmass "c" [range (in_fun in_α in_β)] = in_fun in_α in_β c``
    , ``tmval ("x",Fun Ind Ind) = in_fun in_ind in_ind x``
    ]
  , ``in_fun in_α (in_fun in_β in_ind) P =
        termsem ^tmsig (tyass,tmass) (tyval,tmval) ^P_deep`` )

val _ = export_theory()
