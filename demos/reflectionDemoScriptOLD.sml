open HolKernel Parse boolLib bossLib lcsymtacs reflectionLib

(* (n_imp_and_intro n) converts terms of the form ``P1 /\ ... /\ Pn ==> Q``
   to terms of the form ``P1 ==> ... ==> Pn ==> Q``. *)
fun n_imp_and_intro 0 = ALL_CONV
  | n_imp_and_intro n = REWR_CONV (GSYM AND_IMP_INTRO) THENC
                       (RAND_CONV (n_imp_and_intro (n-1)))

(* given [...,A,...] |- P and H |- A <=> B1 /\ ... /\ Bn
   produce [...,B1,...,Bn,...] ∪ H |- P

   This will not work if any of the Bi's are
   conjunctions. It will raise a HOL_ERR if Bi for i<n
   is a conjunction; conjunction is right-associative,
   so if Bn is a conjunction, the result will be
   different than shown above. *)
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
   produce [...,B1',...,Bn',...] ∪ H |- P

   This will not work if any of the Bi's are
   conjunctions. It will raise a HOL_ERR if Bi for i<n
   is a conjunction; conjunction is right-associative,
   so if Bn is a conjunction, the result will be
   different than shown above. *)
fun replace_assum th simpth =
  let
    val c = simpth |> concl
    val (xs,b) = c |> strip_forall
    val (B,A) = dest_imp b handle HOL_ERR _ => (T,b)
    val A' = first (can (match_term A)) (hyp th)
    val th1 = DISCH A' th
    val (s,_) = match_term A A'
    val th2 = ISPECL (map (fn x => #residue(first (equal (dest_var x) o dest_var o #redex) s)) xs) simpth
    val n = B |> strip_conj |> length
    val th3 = CONV_RULE (n_imp_and_intro (n-1)) th2
    val th4 = funpow n UNDISCH th3 handle HOL_ERR _ => th3
  in
    MP th1 th4
  end

val _ = new_theory"reflectionDemo"

val () = show_assums := true

val p = ``0 = 1``
val res1 = prop_to_loeb_hyp p
val p = ``∀y. (λx. F) z``
val res2 = prop_to_loeb_hyp p
val p = ``(∀y. (λx. F) z) ⇔ (¬z ∨ T)``
val res3 = prop_to_loeb_hyp p
val p = ``∀p. (λx. ~(x=x)) p ⇒ ∃x. F``
val res4 = prop_to_loeb_hyp p
val p = ``∀p. p ∨ ¬p``
val res5 = prop_to_loeb_hyp p
val p = ``(@x. x = x):bool``
val res6 = prop_to_loeb_hyp p
val p = ``@z. z ⇔ (a = @x. F)``
val res7 = prop_to_loeb_hyp p
val p = ``if x then x else F``
val res8 = prop_to_loeb_hyp p
val p = ``∀(x:ind). F``
val res9 = prop_to_loeb_hyp p

open miscLib basicReflectionLib listSimps stringSimps
open setSpecTheory holSemanticsTheory reflectionTheory pairSyntax listSyntax stringSyntax
open holBoolTheory holBoolSyntaxTheory holSyntaxTheory holSyntaxExtraTheory holAxiomsTheory holAxiomsSyntaxTheory
open finite_mapTheory alistTheory listTheory pairTheory

val inhabited_boolset = prove(
  ``is_set_theory ^mem ⇒ inhabited boolset``,
  metis_tac[mem_boolset])

val equality_bool_thm = prove(
  ``is_set_theory ^mem ⇒
    (Abstract (range in_bool) (Funspace (range in_bool) (range in_bool))
       (λx. Abstract (range in_bool) (range in_bool)
         (λy. Boolean (x = y))) =
     Abstract (range in_bool) (Funspace (range in_bool) (range in_bool))
       (λx. Abstract (range in_bool) (range in_bool)
         (λy. Boolean ((x = True) ⇔ (y = True)))))``,
  rw[] >>
  match_mp_tac (UNDISCH abstract_eq) >>
  simp[UNDISCH range_in_bool] >> rw[] >>
  TRY (
    match_mp_tac (UNDISCH abstract_in_funspace) >>
    simp[boolean_in_boolset] ) >>
  match_mp_tac (UNDISCH abstract_eq) >>
  simp[boolean_in_boolset] >>
  rw[boolean_def] >>
  metis_tac[mem_boolset]) |> UNDISCH

local
  val dest_in_fun = dest_triop ``in_fun0`` (mk_HOL_ERR"""dest_in_fun""")
  val range_in_fun0 =
    range_in_fun
    |> Q.GENL[`inb`,`ina`,`mem`]
    |> SIMP_RULE std_ss [GSYM AND_IMP_INTRO]
in
  fun range_in_fun_conv tm =
    let
      val in_fun_ina_inb = rand tm
      val (mem,ina,inb) = dest_in_fun in_fun_ina_inb
      val th = ISPECL[mem,ina,inb] range_in_fun0 |> funpow 3 UNDISCH
    in
      REWR_CONV th tm
    end
end

val inty_var = select_instance_thm |> concl |> funpow 2 rand |> rator |> funpow 3 rand
val ty_var = select_instance_thm |> concl |> funpow 4 rand
             |> lhs |> rator |> funpow 3 rand |>  rator |> rand
val select_fun_var = select_instance_thm |> concl |> rator |> funpow 2 rand
fun mk_range tm = ``range ^tm``
fun mk_select_pair ty =
  let
    val inty = mk_in ty
    val p = mk_var("p",U --> bool)
    val x = mk_var("x",ty)
    val inty_x = mk_comb(inty,x)
  in
    (mk_range inty, mk_abs(p, mk_comb(inty,(mk_select(x,mk_comb(p,inty_x))))))
  end

(*
val res = res4

val seltys = HOLset.listItems (select_types (rand (concl res)))

val (good_select_th,select_instance_ths,select_fun_applied) =
  let
    val pairs = map mk_select_pair seltys
    fun f ((p,q),th) =
      let
        val inty = rand p
        val good = ISPEC inty good_select_extend_base_select |> UNDISCH
      in
        MATCH_MP good th
      end
    val good_th = foldl f (UNDISCH good_select_base_select) pairs
    val all_distinct_asm =
      ASSUME(mk_all_distinct(mk_list(map fst pairs,U)))
      |> SIMP_RULE (std_ss++LIST_ss) [listTheory.ALL_DISTINCT]
    val select_fun_tm = rand(concl good_th)
    fun f range_inty =
      let
        val inty = rand range_inty
        val th =
          mk_comb(select_fun_tm,range_inty)
          |> SIMP_CONV std_ss [combinTheory.APPLY_UPDATE_THM,all_distinct_asm]
      in
        th
      end
    val select_fun_applied = map (f o fst) pairs
    fun f th =
      let
        val tm = th |> concl |> lhs |> rand |> rand
        val insth = IINST1 inty_var tm select_instance_thm
                 |> IINST1 ty_var (type_to_deep (fst(dom_rng(type_of tm))))
                 |> IINST1 select_fun_var (rand(concl good_th))
        val th2 = MP (MP insth good_th) th
               |> CONV_RULE (LAND_CONV (SIMP_CONV (std_ss++LIST_ss) [typesem_def]))
      in
        th2 |> funpow 2 UNDISCH
      end
    val inst_ths = map f select_fun_applied
  in
    (good_th,inst_ths,select_fun_applied)
  end

val select_fun_tm = rand(concl good_select_th)
val model_models = SPEC select_fun_tm select_model_models |> C MP good_select_th
val model_is_bool_interpretation =
  select_bool_interpretation |> DISCH_ALL |> Q.GEN`select` |> SPEC select_fun_tm
  |> C MP good_select_th |> UNDISCH
val model_is_interpretation =
     model_models |> SIMP_RULE std_ss [models_def] |> CONJUNCT2 |> CONJUNCT1 |> CONJUNCT1
val model_is_std =
  model_models |> CONJUNCT2 |> CONJUNCT1 |> SIMP_RULE std_ss [models_def]
  |> CONJUNCT2 |> CONJUNCT1
val model_bool_ty =
  model_is_std |> SIMP_RULE std_ss [is_std_interpretation_def]
               |> CONJUNCT1
               |> SIMP_RULE std_ss [is_std_type_assignment_def]
fun clean_asms th =
  let
    val simpths = mapfilter
      (QCHANGED_CONV (SIMP_CONV (std_ss++LIST_ss)
        [model_bool_ty,UNDISCH range_in_bool,UNDISCH is_in_in_bool]))
      (hyp th)
  in
    foldl (uncurry (C simplify_assum)) th simpths |> PROVE_HYP TRUTH
  end
val select_instance_ths0 = map clean_asms select_instance_ths
*)

val res = res4
val model_models = bool_model_models
val model_is_bool_interpretation = bool_model_interpretation
val select_insts = TRUTH
val model_is_interpretation =
     model_models |> SIMP_RULE std_ss [models_def] |> CONJUNCT2 |> CONJUNCT1
val select_instance_ths0 = []
val select_fun_applied = []
val model_is_std =
  model_models |> CONJUNCT2 |> SIMP_RULE std_ss [models_def]
  |> CONJUNCT2 |> CONJUNCT1

val model = model_models |> concl |> find_term (can (match_term ``X models Y``)) |> rator |> rand
val ctxt = model_models |> concl |> find_term (can (match_term ``thyof ctxt``)) |> funpow 4 rand

val _ = overload_on("the_model",model)
val _ = overload_on("the_ctxt",ctxt)

val select_instance_ths1 =
  map (IINST1 tmsig ``tmsof ^ctxt``) select_instance_ths0

val bool_insts0 =
  DISCH_ALL(CONJ(UNDISCH bool_sig_instances)(UNDISCH bool_sig_quant_instances))
  |> Q.GEN`sig`
  |> Q.SPEC`sigof ^ctxt`
  |> SIMP_RULE std_ss [GSYM CONJ_ASSOC]
val is_bool_sig_goal:goal = ([],fst(dest_imp(concl bool_insts0)))
val is_bool_sig_th = TAC_PROOF(is_bool_sig_goal,
  TRY(
    match_mp_tac (MP_CANON is_bool_sig_extends) >>
    qexists_tac`mk_bool_ctxt init_ctxt` >>
    conj_asm2_tac >- (
      match_mp_tac select_extends >>
      conj_tac >- (match_mp_tac is_bool_sig_std >>
                   pop_assum ACCEPT_TAC ) >>
      EVAL_TAC )) >>
  match_mp_tac bool_has_bool_sig >>
  ACCEPT_TAC (MATCH_MP theory_ok_sig init_theory_ok |> SIMP_RULE std_ss []))
val bool_insts = MP bool_insts0 is_bool_sig_th

val std_insts0 = Q.SPEC`sigof ^ctxt`(Q.GEN`sig`std_sig_instances)
  |> SIMP_RULE std_ss []
val is_std_sig_goal:goal = ([],fst(dest_imp(concl std_insts0)))
val is_std_sig_th = TAC_PROOF(is_std_sig_goal,
  match_mp_tac is_bool_sig_std >>
  ACCEPT_TAC is_bool_sig_th)
val std_insts = MP std_insts0 is_std_sig_th

(*
val select_insts0 = Q.SPEC`sigof ^ctxt`(Q.GEN`sig`select_sig_instances)
  |> SIMP_RULE std_ss []
val is_select_sig_goal:goal = ([],fst(dest_imp(concl select_insts0)))
val is_select_sig_th = TAC_PROOF(is_select_sig_goal,
  match_mp_tac select_has_select_sig >>
  match_mp_tac bool_has_bool_sig >>
  ACCEPT_TAC (MATCH_MP theory_ok_sig init_theory_ok |> SIMP_RULE std_ss []))
val select_insts1 = MP select_insts0 is_select_sig_th
*)
val select_insts1 = TRUTH
val is_select_sig_th = TRUTH

val in_fun_forall1 = in_fun_forall |> DISCH``is_in ina`` |> Q.GEN`ina`
val in_fun_exists1 = in_fun_exists |> DISCH``is_in ina`` |> Q.GEN`ina`
val in_fun_select1 = in_fun_select |> Q.GEN`ina`
val is_instance_quant = prove(
  ``is_instance (Fun (Fun (Tyvar A) Bool) Bool) z ⇔
    ∃y. z = Fun (Fun y Bool) Bool``,
  rw[EQ_IMP_THM] >>
  qexists_tac`[(y,Tyvar A)]` >>
  EVAL_TAC)
val is_instance_equality = prove(
  ``is_instance (Fun (Tyvar A) (Fun (Tyvar A) Bool)) z ⇔
    ∃y. z = Fun y (Fun y Bool)``,
  rw[EQ_IMP_THM] >>
  qexists_tac`[(y,Tyvar A)]` >>
  EVAL_TAC)

fun list_conj x = LIST_CONJ x handle HOL_ERR _ => TRUTH

val model_interpretations = bool_interpretations model_is_bool_interpretation

val tyval_th = mk_tyval res
val r3 = res |> INST[tyval|->(rand(concl tyval_th))]
val select_instance_ths2 =
  map (INST[tyval|->rand(concl tyval_th)]) select_instance_ths1
val simpths = mapfilter (QCHANGED_CONV (SIMP_CONV (std_ss++LIST_ss++STRING_ss) [combinTheory.APPLY_UPDATE_THM])) (hyp r3)
val r4 = foldl (uncurry PROVE_HYP) r3 (map EQT_ELIM simpths)
val r5 = Q.INST[`ctxt`|->`^ctxt`] r4
val is_std_sig_goal:goal = ([],first (can (match_term ``is_std_sig x``)) (hyp r5))
val is_std_sig_th = TAC_PROOF(is_std_sig_goal,
  TRY (
    match_mp_tac (MP_CANON is_std_sig_extends) >>
    match_exists_tac(concl select_extends_bool) >>
    simp[select_extends_bool] >>
    match_mp_tac is_bool_sig_std >>
    match_mp_tac bool_has_bool_sig >>
    ACCEPT_TAC (MATCH_MP theory_ok_sig init_theory_ok |> SIMP_RULE std_ss [])) >>
  match_mp_tac is_bool_sig_std >>
  ACCEPT_TAC is_bool_sig_th)
val r6 = PROVE_HYP is_std_sig_th r5
val bool_sig = is_bool_sig_def
  |> Q.SPEC`sigof(^ctxt)`
  |> SIMP_RULE std_ss [is_bool_sig_th,is_std_sig_th]
val std_sig = CONV_RULE (REWR_CONV is_std_sig_def)
  (MATCH_MP is_bool_sig_std is_bool_sig_th)
  |> SIMP_RULE std_ss []
val select_sig = is_select_sig_def
  |> Q.SPEC`sigof(^ctxt)`
  |> SIMP_RULE std_ss [is_bool_sig_th,is_select_sig_th]
val simpths = mapfilter (QCHANGED_CONV (SIMP_CONV (std_ss++LIST_ss++STRING_ss)
  [combinTheory.APPLY_UPDATE_THM,bool_insts,select_insts1,
   select_sig,bool_sig,std_insts,std_sig,is_instance_refl,
   is_instance_quant,is_instance_equality])) (hyp r6)
val r7 = foldl (uncurry (C simplify_assum)) r6 simpths |> PROVE_HYP TRUTH
val simpths = mapfilter (QCHANGED_CONV (SIMP_CONV (std_ss++LIST_ss++STRING_ss)
  [is_valuation_def,tyval_th,type_11,typesem_def,combinTheory.APPLY_UPDATE_THM])) (hyp r7)
val r8 = foldl (uncurry (C simplify_assum)) r7 simpths |> PROVE_HYP TRUTH
val r9 = Q.INST[`tyass`|->`tyaof ^model`,`tmass`|->`tmaof ^model`] r8
val simpths = mapfilter (QCHANGED_CONV (SIMP_CONV (std_ss)
  [model_models,SIMP_RULE std_ss [models_def] model_models])) (hyp r9)
val r10 = foldl (uncurry (C simplify_assum)) r9 simpths |> PROVE_HYP TRUTH
val forall_insts = filter (can (match_term ``X = in_fun Y in_bool $!``)) (hyp r10)
val exists_insts = filter (can (match_term ``X = in_fun Y in_bool $?``)) (hyp r10)
val select_insts = filter (can (match_term ``X = in_fun Y Z $@``)) (hyp r10)
val forall_insts = map (rand o rator o rand o rator o rator o rhs) forall_insts
val exists_insts = map (rand o rator o rand o rator o rator o rhs) exists_insts
val select_insts = map (rand o rator o rand o rator o rator o rhs) select_insts
val simpths = mapfilter (QCHANGED_CONV (SIMP_CONV (std_ss++LIST_ss) [model_interpretations,
    in_bool_true,in_bool_false,in_fun_not,in_fun_binop,
    list_conj (map (fn ina => ISPEC ina in_fun_forall1 |> UNDISCH) forall_insts),
    list_conj (map (fn ina => ISPEC ina in_fun_exists1 |> UNDISCH) exists_insts),
    list_conj (map (fn ina => ISPEC ina in_fun_select1 |> UNDISCH) select_insts),
    list_conj select_instance_ths2,
    model_is_std
    |> SIMP_RULE std_ss [is_std_interpretation_def,is_std_type_assignment_def,GSYM (UNDISCH range_in_bool)]
    |> CONJUNCT1,
    list_conj (map (UNDISCH o C ISPEC inhabited_range) forall_insts),
    list_conj (map (UNDISCH o C ISPEC inhabited_range) exists_insts),
    UNDISCH inhabited_boolset |>
    SIMP_RULE std_ss [GSYM (UNDISCH range_in_bool)]])) (hyp r10)
val r11 = foldl (uncurry (C simplify_assum)) r10 simpths |> PROVE_HYP TRUTH
val is_term_valuation_asm = first (same_const ``is_term_valuation0`` o fst o strip_comb) (hyp r11)
val t1 = is_term_valuation_asm |> rator |> rator |> rator |> rand
val t2 = is_term_valuation_asm |> rator |> rator |> rand
val t3 = is_term_valuation_asm |> rator |> rand
val asms = tmval_asms r11
val tmval_th1 =
  constrained_term_valuation_exists
  |> UNDISCH
  |> SPECL [t1,t2,t3]
  |> SIMP_RULE std_ss [tyval_th]
  |> C MP (
       model_is_interpretation
       |> SIMP_RULE std_ss [is_interpretation_def] |> CONJUNCT1)
  |> SPEC (asms |> map (fn eq => mk_pair(rand(lhs eq),rhs eq))
           |> C (curry mk_list) (mk_prod(mk_prod(string_ty,``:type``),U)))
val goal = (hyp tmval_th1,fst(dest_imp(concl tmval_th1)))
val tmval_th2 = TAC_PROOF(goal,
  conj_tac >- EVAL_TAC >>
  simp[holSyntaxTheory.type_ok_def,typesem_def,combinTheory.APPLY_UPDATE_THM] >>
  rpt conj_tac >>
  TRY (EVAL_TAC >> NO_TAC) >>
  TRY (simp[
    model_is_bool_interpretation
    |> SIMP_RULE std_ss [is_bool_interpretation_def] |> CONJUNCT1
    |> SIMP_RULE std_ss [is_std_interpretation_def] |> CONJUNCT1
    |> SIMP_RULE std_ss [is_std_type_assignment_def]
    |> CONJUNCT2] >>
    metis_tac[is_in_in_bool,is_in_range_thm,range_in_bool]) >>
  metis_tac[is_in_range_thm])
val tmval_th3 = MP tmval_th1 tmval_th2
  |> SIMP_RULE (std_ss++LIST_ss)[]

(** code below doesn't currently work
val r12 =
  foldl (uncurry PROVE_HYP) r11 (CONJUNCTS (ASSUME (mk_conj(is_term_valuation_asm,(list_mk_conj asms)))))
val r13 = CHOOSE (tmval, tmval_th3) r12
  |> PROVE_HYP (UNDISCH is_in_in_bool)
val simpths = mapfilter (QCHANGED_CONV (SIMP_CONV std_ss select_fun_applied)) (hyp r13)
val r14 = foldl (uncurry (C simplify_assum)) r13 simpths
val simpths = mapfilter (QCHANGED_CONV
  (ONCE_DEPTH_CONV range_in_fun_conv THENC
   SIMP_CONV std_ss [UNDISCH range_in_bool,type_11])) (hyp r14)
val r15 = foldl (uncurry (C simplify_assum)) r14 simpths |> PROVE_HYP TRUTH
val simpths = mapfilter (QCHANGED_CONV (SIMP_CONV std_ss
  [GSYM(UNDISCH range_in_bool), UNDISCH is_in_in_bool, equality_bool_thm])) (hyp r15)
val r16 = foldl (uncurry (C simplify_assum)) r15 simpths |> PROVE_HYP TRUTH

val _ = save_thm("example",r16)
**)

val _ = export_theory()
