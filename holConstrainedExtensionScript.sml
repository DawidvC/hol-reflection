open HolKernel boolLib bossLib lcsymtacs miscLib
open miscTheory finite_mapTheory alistTheory listTheory pairTheory pred_setTheory
open holSyntaxLibTheory holSyntaxTheory holSyntaxExtraTheory holSemanticsTheory holSemanticsExtraTheory holExtensionTheory
val _ = ParseExtras.temp_tight_equality()
val _ = new_theory"holConstrainedExtension"

val mem = ``mem:'U->'U->bool``

(* TODO: move *)

val UPDATE_LIST_NOT_MEM = store_thm("UPDATE_LIST_NOT_MEM",
  ``∀ls f x. ¬MEM x(MAP FST ls) ⇒ (f =++ ls) x = f x``,
  Induct >> simp[UPDATE_LIST_THM,combinTheory.APPLY_UPDATE_THM])

val MAP_ZIP_UPDATE_LIST_ALL_DISTINCT_same = store_thm("MAP_ZIP_UPDATE_LIST_ALL_DISTINCT_same",
  ``∀ks vs f. LENGTH ks = LENGTH vs ∧ ALL_DISTINCT ks ⇒ (MAP (f =++ ZIP (ks,vs)) ks = vs)``,
  Induct >> simp[LENGTH_NIL_SYM] >>
  gen_tac >> Cases >> simp[UPDATE_LIST_THM] >>
  simp[UPDATE_LIST_NOT_MEM,MAP_ZIP,combinTheory.APPLY_UPDATE_THM])

val is_type_valuation_UPDATE_LIST = store_thm("is_type_valuation_UPDATE_LIST",
  ``∀t ls. is_type_valuation t ∧ EVERY (inhabited o SND) ls ⇒
           is_type_valuation (t =++ ls)``,
  rw[is_type_valuation_def,APPLY_UPDATE_LIST_ALOOKUP] >>
  BasicProvers.CASE_TAC >> rw[] >> imp_res_tac ALOOKUP_MEM >>
  fs[EVERY_MEM,FORALL_PROD] >> metis_tac[])

val tyvars_Tyapp_MAP_Tyvar = store_thm("tyvars_Tyapp_MAP_Tyvar",
  ``∀x ls. ALL_DISTINCT ls ⇒ (tyvars (Tyapp x (MAP Tyvar ls)) = LIST_UNION [] ls)``,
  simp[tyvars_def] >>
  Induct >> fs[tyvars_def,LIST_UNION_def] >>
  rw[LIST_INSERT_def])

val STRING_SORT_SET_TO_LIST_set_tvars = store_thm("STRING_SORT_SET_TO_LIST_set_tvars",
  ``∀tm. STRING_SORT (SET_TO_LIST (set (tvars tm))) = STRING_SORT (tvars tm)``,
  gen_tac >> mp_tac(SPEC_ALL tvars_ALL_DISTINCT) >>
  REWRITE_TAC[sortingTheory.ALL_DISTINCT_PERM_LIST_TO_SET_TO_LIST] >>
  strip_tac >>
  simp[STRING_SORT_EQ,sortingTheory.PERM_SYM])

(* -- *)

val types_in_def = Define`
  types_in (Var x ty) = {ty} ∧
  types_in (Const c ty) = {ty} ∧
  types_in (Comb t1 t2) = types_in t1 ∪ types_in t2 ∧
  types_in (Abs x ty t) = ty INSERT types_in t`
val _ = export_rewrites["types_in_def"]

val type_ok_types_in = store_thm("type_ok_types_in",
  ``∀sig. is_std_sig sig ⇒ ∀tm ty. term_ok sig tm ∧ ty ∈ types_in tm ⇒ type_ok (tysof sig) ty``,
  gen_tac >> strip_tac >> Induct >> simp[] >> rw[] >>
  TRY (imp_res_tac term_ok_def >> NO_TAC) >> fs[term_ok_def])

(* maybe the above too *)

val constrainable_update_def = Define`
  constrainable_update upd ⇔
    ∃vars.
      FINITE vars ∧
      EVERY ($= vars) (MAP (set o tvars) (axioms_of_upd upd)) ∧
      EVERY ($= vars) (MAP (set o tyvars o SND) (consts_of_upd upd)) ∧
      let all_types =
        BIGUNION (set (MAP types_in (axioms_of_upd upd))) ∪
        set (MAP SND (consts_of_upd upd)) in
      ∀name arity.
        MEM (name,arity) (types_of_upd upd) ⇒
        arity = CARD vars ∧
        ∀args. Tyapp name args ∈ all_types ⇒
               args = MAP Tyvar (STRING_SORT (SET_TO_LIST vars))`

val TypeDefn_constrainable = store_thm("TypeDefn_constrainable",
  ``∀name pred abs rep ctxt.
    TypeDefn name pred abs rep updates ctxt ∧
    is_std_sig (sigof ctxt) ⇒
    constrainable_update (TypeDefn name pred abs rep)``,
  rw[updates_cases] >>
  `MEM "fun" (MAP FST (type_list ctxt)) ∧ MEM "bool" (MAP FST (type_list ctxt))` by (
    fs[is_std_sig_def] >>
    imp_res_tac ALOOKUP_MEM >>
    fs[MEM_MAP,EXISTS_PROD] >>
    metis_tac[] ) >>
  `∃repty. typeof pred = Fun repty Bool ∧ (∀x. MEM x (tyvars repty) ⇒ MEM x (tvars pred))` by (
    imp_res_tac proves_term_ok >> fs[term_ok_def] >>
    imp_res_tac WELLTYPED_LEMMA >> fs[] >> rfs[] >>
    rw[] >> imp_res_tac tyvars_typeof_subset_tvars >>
    fs[tyvars_def,tvars_def] >>
    `MEM x (tyvars (typeof pred))` by simp[tyvars_def] >>
    fs[WELLTYPED] >>
    imp_res_tac tyvars_typeof_subset_tvars >>
    fs[tyvars_def,SUBSET_DEF]) >>
  `∀args'. Tyapp name args' ∉ types_in pred ∧ Tyapp name args' ≠ repty ∧ Tyapp name args' ≠ Bool` by (
    imp_res_tac proves_term_ok >> fs[term_ok_def] >>
    rw[] >>
    spose_not_then strip_assume_tac >>
    imp_res_tac type_ok_types_in >>
    imp_res_tac term_ok_type_ok >>
    fs[type_ok_def] >>
    rw[] >> rfs[type_ok_def] >>
    imp_res_tac ALOOKUP_MEM >>
    fs[MEM_MAP,EXISTS_PROD] >>
    metis_tac[] ) >>
  simp[constrainable_update_def,ALL_DISTINCT_CARD_LIST_TO_SET] >>
  simp[tyvars_def,Q.SPECL[`set s`,`set t`]EXTENSION,MEM_FOLDR_LIST_UNION,MEM_MAP,PULL_EXISTS,EVERY_MAP] >>
  conj_tac >- (
    simp[conexts_of_upd_def,tvars_def,equation_def,tyvars_def] >>
    simp[EXTENSION,MEM_FOLDR_LIST_UNION,MEM_MAP,PULL_EXISTS,tyvars_def] >>
    rw[EQ_IMP_THM] >> rw[] >>
    imp_res_tac proves_term_ok >> fs[Once has_type_cases] >>
    imp_res_tac WELLTYPED_LEMMA >> fs[tyvars_def] ) >>
  conj_tac >- metis_tac[] >>
  ONCE_REWRITE_TAC[GSYM LIST_TO_SET_APPEND] >>
  ONCE_REWRITE_TAC[GSYM tyvars_def] >>
  simp[tyvars_Tyapp_MAP_Tyvar] >>
  fs[GSYM SUBSET_DEF,SUBSET_UNION_ABSORPTION] >>
  simp[GSYM ALL_DISTINCT_CARD_LIST_TO_SET,ALL_DISTINCT_LIST_UNION] >>
  simp[STRING_SORT_SET_TO_LIST_set_tvars] >>
  simp[conexts_of_upd_def,tvars_def,equation_def,tyvars_def] >>
  rw[] >> fs[] >> rw[] >> fs[] >> TRY(metis_tac[]))

val _ = Parse.type_abbrev("constraints",``:'U list -> ('U list # 'U list) option``)

val constrain_assignment_def = Define`
  constrain_assignment cs p ns f =
    λname args. case cs args of NONE => f name args
    | SOME x => case ALOOKUP (ZIP(ns,p x)) name of NONE => f name args
                   | SOME v => v`

val _ = Parse.overload_on("constrain_tyass",
  ``λcs upd. constrain_assignment cs FST (MAP FST (types_of_upd upd))``)
val _ = Parse.overload_on("constrain_tmass",
  ``λcs upd. constrain_assignment cs SND (MAP FST (consts_of_upd upd))``)

val constrain_interpretation_def = Define`
  constrain_interpretation upd cs ((δ,γ):'U interpretation) =
    (constrain_tyass cs upd δ,
     constrain_tmass cs upd γ)`

val tyvars_of_upd_def = new_specification("tyvars_of_upd_def",["tyvars_of_upd"],
  constrainable_update_def |> SPEC_ALL
  |> EQ_IMP_RULE |> fst
  |> CONV_RULE(HO_REWR_CONV (GSYM RIGHT_EXISTS_IMP_THM))
  |> GEN_ALL
  |> CONV_RULE(HO_REWR_CONV SKOLEM_THM))

val well_formed_constraints_def = xDefine"well_formed_constraints"`
  well_formed_constraints0 ^mem upd cs δ ⇔
    ∀vs tyvs tmvs.
        cs vs = SOME (tyvs,tmvs) ⇒
        EVERY inhabited vs ∧
        LENGTH tyvs = LENGTH (types_of_upd upd) ∧
        EVERY inhabited tyvs ∧
        let vars = STRING_SORT (SET_TO_LIST (tyvars_of_upd upd)) in
        LENGTH vars = LENGTH vs ∧
        ∀τ. is_type_valuation τ ∧ MAP τ vars = vs ⇒
          LIST_REL (λv ty. v <: typesem (constrain_tyass cs upd δ) τ ty)
            tmvs (MAP SND (consts_of_upd upd))`
val _ = Parse.overload_on("well_formed_constraints",``well_formed_constraints0 ^mem``)

val constrain_interpretation_equal_on = store_thm("constrain_interpretation_equal_on",
  ``is_set_theory ^mem ⇒
    ∀upd cs i ctxt.
      constrainable_update upd ∧
      well_formed_constraints upd cs (tyaof i) ∧ upd updates ctxt ∧ ctxt extends init_ctxt
      ⇒
      equal_on ctxt i (constrain_interpretation upd cs i)``,
  rw[] >> Cases_on`i` >>
  fs[equal_on_def,constrain_interpretation_def] >>
  fs[well_formed_constraints_def,constrain_assignment_def] >>
  simp[FUN_EQ_THM] >>
  `upd::ctxt extends init_ctxt` by (
    simp[extends_def,Once relationTheory.RTC_CASES1] >>
    simp[GSYM extends_def] ) >>
  pop_assum(mp_tac o MATCH_MP extends_ALL_DISTINCT) >>
  simp[init_ALL_DISTINCT,ALL_DISTINCT_APPEND] >> strip_tac >>
  rw[term_ok_def,type_ok_def] >>
  BasicProvers.CASE_TAC >>
  BasicProvers.CASE_TAC >>
  imp_res_tac ALOOKUP_MEM >>
  Cases_on`x`>>fs[]>>res_tac>>
  fs[LET_THM,LIST_REL_EL_EQN] >>
  fs[ZIP_MAP,MEM_MAP,PULL_EXISTS,FORALL_PROD] >>
  imp_res_tac MEM_ZIP_MEM_MAP >> rfs[] >>
  TRY(PairCases_on`p`>>fs[] >> metis_tac[]) >>
  qmatch_assum_abbrev_tac`LENGTH vars = LENGTH args` >>
  first_x_assum(qspec_then`K boolset =++ ZIP(vars,args)`mp_tac) >>
  discharge_hyps >- (
    conj_tac >- (
      match_mp_tac is_type_valuation_UPDATE_LIST >>
      simp[EVERY_MEM,is_type_valuation_def] >>
      conj_tac >- metis_tac[setSpecTheory.boolean_in_boolset] >>
      simp[MEM_ZIP,PULL_EXISTS] >>
      fs[EVERY_MEM,MEM_EL,PULL_EXISTS]) >>
    match_mp_tac MAP_ZIP_UPDATE_LIST_ALL_DISTINCT_same >>
    simp[Abbr`vars`] ) >>
  rw[] >> fs[MEM_MAP,EXISTS_PROD] >> metis_tac[])

val valid_constraints_def = xDefine"valid_constraints"`
  valid_constraints0 ^mem ctxt upd cs i ⇔
    ∀v.
      is_valuation (tysof (upd::ctxt))
        (tyaof (constrain_interpretation upd cs i))
        v ∧
      IS_SOME (cs (MAP (tyvof v) (STRING_SORT (SET_TO_LIST (tyvars_of_upd upd)))))
      ⇒
      ∀p. MEM p (axioms_of_upd upd) ⇒
        termsem (tmsof (upd::ctxt))
          (constrain_interpretation upd cs i)
          v p = True`
val _ = Parse.overload_on("valid_constraints",``valid_constraints0 ^mem``)

(*
val add_constraints_thm = store_thm("add_constraints_thm",
  ``is_set_theory ^mem ⇒
    ∀i upd ctxt cs.
      constrainable_update upd ∧
      upd updates ctxt ∧ ctxt extends init_ctxt ∧
      i models (thyof (upd::ctxt)) ∧
      well_formed_constraints upd cs (tyaof i) ∧
      valid_constraints ctxt upd cs i
      ⇒
      constrain_interpretation upd cs i models thyof (upd::ctxt)``,
  rw[] >> fs[models_def] >>
  REWRITE_TAC[CONJ_ASSOC] >>
  `theory_ok (thyof ctxt)` by metis_tac[extends_theory_ok,init_theory_ok] >>
  `theory_ok (thyof (upd::ctxt))` by metis_tac[updates_theory_ok] >>
  `∃δ γ. i =(δ,γ)` by metis_tac[pair_CASES] >>
  `ALL_DISTINCT (MAP FST (type_list (upd::ctxt))) ∧
   ALL_DISTINCT (MAP FST (const_list (upd::ctxt)))` by (
    conj_tac >>
    imp_res_tac updates_ALL_DISTINCT >>
    first_x_assum match_mp_tac >>
    imp_res_tac extends_ALL_DISTINCT >>
    first_x_assum match_mp_tac >>
    EVAL_TAC ) >>
  conj_asm1_tac >- (
    fs[is_interpretation_def,is_std_interpretation_def,constrain_interpretation_def] >>
    simp[GSYM CONJ_ASSOC] >>
    conj_tac >- (
      fs[is_type_assignment_def,FEVERY_ALL_FLOOKUP] >> rw[] >>
      res_tac >> rw[constrain_assignment_def] >>
      BasicProvers.CASE_TAC >> rw[] >>
      fs[FLOOKUP_FUNION] >>
      BasicProvers.CASE_TAC >- metis_tac[] >>
      fs[well_formed_constraints_def] >>
      qmatch_assum_rename_tac`cs ls = SOME p`[]>>
      PairCases_on`p`>>res_tac>>
      imp_res_tac ALOOKUP_MEM>>
      rfs[ZIP_MAP,MEM_MAP] >>
      rfs[EVERY_MEM,MEM_ZIP] >>
      metis_tac[MEM_EL]) >>
    CONV_TAC(lift_conjunct_conv(can (match_term ``is_std_type_assignment X``))) >>
    conj_asm1_tac >- (
      fs[is_std_type_assignment_def,constrain_assignment_def] >>
      imp_res_tac theory_ok_sig >>
      fs[is_std_sig_def,IS_SOME_EXISTS,PULL_EXISTS] >>
      imp_res_tac ALOOKUP_MEM >>
      rw[] >> fs[ALL_DISTINCT_APPEND] >>
      BasicProvers.CASE_TAC >>
      res_tac >> fs[] >> rw[] >>
      rpt (BasicProvers.CASE_TAC >> res_tac >> fs[]) >>
      fs[well_formed_constraints_def] >>
      qmatch_assum_rename_tac`cs ls = SOME p`["ls"]>>
      PairCases_on`p`>>res_tac>>
      imp_res_tac ALOOKUP_MEM >> rfs[MEM_MAP,EXISTS_PROD,ZIP_MAP]>>
      imp_res_tac MEM_ZIP_MEM_MAP >> rfs[] >>
      metis_tac[]) >>
    conj_tac >- (
      fs[interprets_def,constrain_assignment_def] >> rw[] >>
      BasicProvers.CASE_TAC >>
      BasicProvers.CASE_TAC >>
      imp_res_tac ALOOKUP_MEM >>
      fs[well_formed_constraints_def] >>
      qmatch_assum_rename_tac`cs ls = SOME p`["ls"]>>
      PairCases_on`p`>>res_tac>>
      fs[LET_THM] >>
      qmatch_assum_abbrev_tac`LENGTH ls = 1` >>
      first_x_assum(qspec_then`(HD ls =+ (τ"A")) (K boolset)`mp_tac) >>
      discharge_hyps >- (
        Cases_on`ls`>>fs[LENGTH_NIL] >>
        simp[is_type_valuation_def,combinTheory.APPLY_UPDATE_THM] >>
        rw[] >> metis_tac[setSpecTheory.boolean_in_boolset]) >> strip_tac >>
      imp_res_tac LIST_REL_LENGTH >> fs[] >>
      imp_res_tac MEM_ZIP_MEM_MAP >> rfs[] >>
      imp_res_tac theory_ok_sig >>
      fs[is_std_sig_def] >>
      imp_res_tac ALOOKUP_MEM >>
      fs[ALL_DISTINCT_APPEND,MEM_MAP,PULL_EXISTS,EXISTS_PROD] >>
      metis_tac[]) >>
    fs[is_term_assignment_def,FEVERY_ALL_FLOOKUP] >> rw[] >>
    first_x_assum(fn th => first_assum(strip_assume_tac o MATCH_MP th)) >>
    first_x_assum(fn th => first_assum(strip_assume_tac o MATCH_MP th)) >>
    rw[constrain_assignment_def] >>
    reverse BasicProvers.CASE_TAC >- (
      fs[well_formed_constraints_def] >>
      qmatch_assum_rename_tac`cs ls = SOME p`["ls"]>>
      PairCases_on`p`>>
      first_assum(fn th => first_x_assum(strip_assume_tac o MATCH_MP th)) >>
      fs[LET_THM] >>
      qpat_assum`FLOOKUP X Y = Z`mp_tac >>
      simp[FLOOKUP_FUNION] >>
      BasicProvers.CASE_TAC >- (
        BasicProvers.CASE_TAC >- (
          rw[] >>
          qmatch_abbrev_tac`m <: typesem d1 τ v` >>
          qsuff_tac`typesem d1 τ v = typesem δ τ v` >- rw[] >>
          match_mp_tac typesem_consts >>
          qexists_tac`tysof ctxt` >>
          conj_tac >- (
            fs[theory_ok_def] >>
            first_x_assum match_mp_tac >>
            simp[IN_FRANGE_FLOOKUP] >>
            metis_tac[] ) >>
          simp[type_ok_def,Abbr`d1`,FUN_EQ_THM] >> rw[] >>
          BasicProvers.CASE_TAC >>
          BasicProvers.CASE_TAC >>
          qmatch_assum_rename_tac`cs ls = SOME p`["ls"]>>
          PairCases_on`p`>>
          res_tac >> fs[ZIP_MAP] >>
          imp_res_tac ALOOKUP_MEM >>
          fs[MEM_MAP] >>
          imp_res_tac MEM_ZIP_MEM_MAP >>
          rfs[] >>
          PairCases_on`p`>>fs[ALL_DISTINCT_APPEND,MEM_MAP,PULL_EXISTS,EXISTS_PROD] >>
          metis_tac[] ) >>
        strip_tac >>
        imp_res_tac ALOOKUP_MEM >>
        qpat_assum`∀X. Y`mp_tac >>
        qpat_abbrev_tac`vars = STRING_SORT X` >>
        disch_then(qspec_then`K boolset =++ ZIP(vars,MAP τ (STRING_SORT (tyvars v)))`mp_tac) >>
        discharge_hyps >- (
          conj_tac >- (
            match_mp_tac is_type_valuation_UPDATE_LIST >>
            simp[EVERY_MEM,is_type_valuation_def] >>
            conj_tac >- metis_tac[setSpecTheory.boolean_in_boolset] >>
            simp[MEM_ZIP,PULL_EXISTS] >>
            fs[EVERY_MEM,MEM_EL,PULL_EXISTS]) >>
          match_mp_tac MAP_ZIP_UPDATE_LIST_ALL_DISTINCT_same >>
          simp[Abbr`vars`] ) >>
        strip_tac >> imp_res_tac LIST_REL_LENGTH >>
        imp_res_tac MEM_ZIP_MEM_MAP >>
        rfs[] >>
        fs[MEM_MAP,EXISTS_PROD,ALL_DISTINCT_APPEND,PULL_EXISTS] >>
        metis_tac[]) >>
      rw[] >>
      `STRING_SORT (SET_TO_LIST (tyvars_of_upd upd)) = STRING_SORT (tyvars v)` by (
        imp_res_tac tyvars_of_upd_def >>
        simp[STRING_SORT_EQ,ALL_DISTINCT_SET_TO_LIST] >>
        imp_res_tac ALOOKUP_MEM >>
        fs[EVERY_MAP,EVERY_MEM] >> res_tac >> fs[] >>
        metis_tac[sortingTheory.ALL_DISTINCT_PERM_LIST_TO_SET_TO_LIST,
                  sortingTheory.PERM_SYM,tyvars_ALL_DISTINCT]) >>
      first_x_assum(qspec_then`τ`mp_tac) >>
      simp[] >>
      strip_tac >> imp_res_tac LIST_REL_LENGTH >>
      BasicProvers.CASE_TAC >- (
        imp_res_tac ALOOKUP_FAILS >>
        imp_res_tac ALOOKUP_MEM >>
        rfs[MEM_MAP,ZIP_MAP,EXISTS_PROD] >>
        rfs[MEM_ZIP,MEM_EL] >>
        metis_tac[] ) >>
      imp_res_tac ALOOKUP_MEM >>
      rfs[LIST_REL_EL_EQN,MEM_ZIP] >>
      first_x_assum(qspec_then`n`mp_tac) >> simp[] >>
      fs[ALL_DISTINCT_APPEND] >>
      `v = EL n (MAP SND (consts_of_upd upd))` by (
        imp_res_tac ALOOKUP_ALL_DISTINCT_EL >> fs[EL_MAP] ) >>
      simp[] >>
      qmatch_abbrev_tac`m <: x1 ⇒ m <: x2` >>
      qsuff_tac`x1 = x2`>-rw[]>>
      unabbrev_all_tac >>
      match_mp_tac typesem_consts >>
      qexists_tac`tysof(upd::ctxt)` >>
      simp[FUN_EQ_THM,constrain_assignment_def] >>
      fs[theory_ok_def] >>
      first_x_assum match_mp_tac >>
      simp[IN_FRANGE_FLOOKUP,FLOOKUP_FUNION] >>
      qexists_tac`EL n (MAP FST (consts_of_upd upd))` >>
      simp[]) >>
    Cases_on`type_ok (tysof ctxt) v` >- (
      qmatch_abbrev_tac`a <: b` >>
      qmatch_assum_abbrev_tac`a <: c` >>
      qsuff_tac `b = c` >- rw[] >>
      unabbrev_all_tac >>
      match_mp_tac typesem_consts >>
      first_assum(match_exists_tac o concl) >> simp[] >>
      simp[type_ok_def] >> rw[FUN_EQ_THM] >>
      BasicProvers.CASE_TAC >>
      BasicProvers.CASE_TAC >>
      fs[well_formed_constraints_def,ALL_DISTINCT_APPEND] >>
      qmatch_assum_rename_tac`cs ls = SOME p`["ls"]>>
      PairCases_on`p`>>res_tac>>
      imp_res_tac ALOOKUP_MEM >> rfs[MEM_MAP,EXISTS_PROD,ZIP_MAP]>>
      imp_res_tac MEM_ZIP_MEM_MAP >> rfs[] >>
      metis_tac[]) >>
    qpat_assum`FLOOKUP X Y = Z`mp_tac >>
    simp[FLOOKUP_FUNION] >>
    BasicProvers.CASE_TAC >- (
      strip_tac >>
      fs[theory_ok_def] >>
      qsuff_tac`F`>-rw[]>>
      qpat_assum`¬x`mp_tac >>simp[]>>
      first_x_assum match_mp_tac >>
      simp[IN_FRANGE_FLOOKUP] >>
      metis_tac[] ) >>
    rw[] >>
    qmatch_abbrev_tac`a <: b` >>
    qmatch_assum_abbrev_tac`a <: c` >>
    qsuff_tac `b = c` >- rw[] >>
    unabbrev_all_tac >>
    fs[Once updates_cases] >> rw[] >> fs[] >- (
      rpt AP_THM_TAC >> AP_TERM_TAC >> rw[FUN_EQ_THM] >>
      BasicProvers.CASE_TAC >>
      BasicProvers.CASE_TAC >>
      fs[well_formed_constraints_def] >>
      qmatch_assum_rename_tac`cs ls = SOME p`["ls"]>>
      PairCases_on`p`>>res_tac>>
      fs[LENGTH_NIL]) >>
    qmatch_abbrev_tac`typesem d1 τ v = typesem δ τ v` >>
    `is_std_type_assignment d1 ∧
     is_std_type_assignment δ` by (
       reverse conj_asm2_tac >- fs[is_std_interpretation_def] >>
       simp[Abbr`d1`,GSYM constrain_assignment_def] ) >>
    rator_x_assum`ALOOKUP` mp_tac >> simp[] >>
    Q.PAT_ABBREV_TAC`t1 = domain (typeof pred)` >>
    Q.PAT_ABBREV_TAC`t2 = Tyapp name X` >>
    qsuff_tac`k ∈ {abs;rep} ∧ (set (tyvars v) = set (tyvars (Fun t1 t2))) ⇒
              (typesem d1 τ t1 = typesem δ τ t1) ∧
              (typesem d1 τ t2 = typesem δ τ t2)` >- (
      match_mp_tac SWAP_IMP >> strip_tac >>
      discharge_hyps >- (
        pop_assum mp_tac >> rw[] >>
        simp[tyvars_def] >>
        metis_tac[pred_setTheory.UNION_COMM] ) >>
      pop_assum mp_tac >>
      rw[] >>
      qmatch_abbrev_tac`typesem d1 τ (Fun dom rng) = typesem δ τ (Fun dom rng)` >>
      qspecl_then[`δ`,`τ`,`dom`,`rng`]mp_tac typesem_Fun >>
      qspecl_then[`d1`,`τ`,`dom`,`rng`]mp_tac typesem_Fun >>
      simp[] >> rw[]) >>
    strip_tac >>
    conj_tac >- (
      unabbrev_all_tac >>
      match_mp_tac typesem_consts >>
      qexists_tac`tysof (ctxt)` >>
      imp_res_tac proves_term_ok >>
      qpat_assum`k ∈ X`kall_tac >>
      fs[term_ok_def] >>
      conj_tac >- (
        imp_res_tac term_ok_type_ok >>
        fs[theory_ok_def] ) >>
      simp[type_ok_def] >> rw[FUN_EQ_THM] >>
      BasicProvers.CASE_TAC >>
      BasicProvers.CASE_TAC >>
      fs[well_formed_constraints_def] >>
      qmatch_assum_rename_tac`cs ls = SOME p`["ls"]>>
      PairCases_on`p`>>res_tac>>
      imp_res_tac ALOOKUP_MEM >> rfs[MEM_MAP,EXISTS_PROD,ZIP_MAP]>>
      imp_res_tac MEM_ZIP_MEM_MAP >> rfs[] >>
      metis_tac[]) >>
    unabbrev_all_tac >>
    simp[typesem_def,MAP_MAP_o,combinTheory.o_DEF,ETA_AX] >>
    BasicProvers.CASE_TAC >>
    BasicProvers.CASE_TAC >>
    qsuff_tac`set (tyvars v) = set (tvars pred)` >- (
      qpat_assum`set (tyvars v) = X`kall_tac >>
      rw[] >>
      `STRING_SORT (tvars pred) = STRING_SORT (tyvars v)` by (
        `ALL_DISTINCT (tvars pred)` by simp[] >>
        `ALL_DISTINCT (tyvars v)` by simp[] >>
        `PERM (tvars pred) (tyvars v)` by (
          match_mp_tac sortingTheory.PERM_ALL_DISTINCT >>
          fs[pred_setTheory.EXTENSION] ) >>
        metis_tac[holSyntaxLibTheory.STRING_SORT_EQ] ) >>
      fs[IS_SOME_EXISTS,PULL_EXISTS,LET_THM] >>
      metis_tac[optionTheory.NOT_SOME_NONE] ) >>
    simp[tyvars_def,pred_setTheory.EXTENSION,
         holSyntaxLibTheory.MEM_FOLDR_LIST_UNION,
         MEM_MAP,PULL_EXISTS] >>
    qpat_assum`k ∈ X`kall_tac >>
    imp_res_tac proves_term_ok >> fs[term_ok_def] >>
    fs[WELLTYPED] >>
    imp_res_tac tyvars_typeof_subset_tvars >>
    fs[pred_setTheory.SUBSET_DEF,tyvars_def] >>
    metis_tac[] ) >>
  gen_tac >>
  qmatch_abbrev_tac`P ⇒ q` >>
  strip_tac >> qunabbrev_tac`q` >>
  first_x_assum(qspec_then`p`mp_tac) >>
  simp[] >> strip_tac >>
  Cases_on`MEM p (axiom_list ctxt)` >- (
    fs[Abbr`P`] >>
    `term_ok (sigof ctxt) p` by (
      fs[theory_ok_def]) >>
    imp_res_tac theory_ok_sig >>
    match_mp_tac satisfies_extend >>
    map_every qexists_tac[`tysof ctxt`,`tmsof ctxt`] >>
    simp[] >>
    REWRITE_TAC[CONJ_ASSOC] >>
    conj_asm1_tac >- (
      conj_tac >>
      match_mp_tac SUBMAP_FUNION >>
      disj2_tac >>
      fs[ALL_DISTINCT_APPEND,pred_setTheory.IN_DISJOINT] >>
      metis_tac[] ) >>
    match_mp_tac satisfies_consts >>
    qexists_tac`i` >> simp[] >> fs[] >>
    simp[term_ok_def,type_ok_def] >>
    REWRITE_TAC[CONJ_ASSOC] >>
    conj_tac >- (
      rw[constrain_interpretation_def,constrain_assignment_def,FUN_EQ_THM] >>
      BasicProvers.CASE_TAC >>
      BasicProvers.CASE_TAC >>
      fs[well_formed_constraints_def,ALL_DISTINCT_APPEND,EXISTS_PROD] >>
      qmatch_assum_rename_tac`cs ls = SOME q`["ls"]>>
      PairCases_on`q`>>res_tac>>
      TRY(
        fs[LET_THM]>>
        qpat_assum`∀X. Y`mp_tac >>
        qpat_abbrev_tac`vars = STRING_SORT X` >>
        disch_then(qspec_then`K boolset =++ ZIP(vars,x)`mp_tac) >>
        discharge_hyps >- (
          conj_tac >- (
            match_mp_tac is_type_valuation_UPDATE_LIST >>
            simp[EVERY_MEM,is_type_valuation_def] >>
            conj_tac >- metis_tac[setSpecTheory.boolean_in_boolset] >>
            simp[MEM_ZIP,PULL_EXISTS] >>
            fs[EVERY_MEM,MEM_EL,PULL_EXISTS]) >>
          match_mp_tac MAP_ZIP_UPDATE_LIST_ALL_DISTINCT_same >>
          simp[Abbr`vars`] ) >>
        strip_tac >> imp_res_tac LIST_REL_LENGTH) >>
      imp_res_tac ALOOKUP_MEM >> rfs[MEM_MAP,EXISTS_PROD,ZIP_MAP]>>
      imp_res_tac MEM_ZIP_MEM_MAP >> rfs[] >>
      metis_tac[]) >>
    fs[satisfies_def] >> rw[] >>
    qmatch_assum_abbrev_tac`tmsof ctxt ⊑ tmsig` >>
    qmatch_assum_abbrev_tac`tysof ctxt ⊑ tysig` >>
    first_assum(
      mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO](UNDISCH extend_valuation_exists))) >>
    first_assum(fn th => disch_then (mp_tac o C MATCH_MP th)) >>
    discharge_hyps >- fs[is_interpretation_def] >> strip_tac >>
    first_x_assum(qspec_then`v'`mp_tac) >> simp[] >>
    disch_then (SUBST1_TAC o SYM) >>
    match_mp_tac EQ_TRANS >>
    qexists_tac`termsem (tmsof ctxt) (δ,γ) v' p` >>
    conj_tac >- (
      match_mp_tac termsem_frees >>
      simp[] >> rw[] >>
      first_x_assum match_mp_tac >>
      imp_res_tac term_ok_VFREE_IN >>
      fs[term_ok_def] ) >>
    metis_tac[termsem_extend]) >>
  fs[valid_constraints_def] >>
  simp[satisfies_def] >>
  rw[] >>
  first_x_assum(qspec_then`v`mp_tac) >>
  qpat_abbrev_tac`P = IS_SOME X` >>
  Cases_on`P` >- (
    disch_then(match_mp_tac o MP_CANON) >>
    simp[] >>
    fs[markerTheory.Abbrev_def]) >>
  simp[] >> pop_assum mp_tac >>
  simp[markerTheory.Abbrev_def] >> strip_tac >>
  fs[satisfies_def] >>
  first_x_assum(qspec_then`v`mp_tac) >>
  discharge_hyps >- (
    fs[is_valuation_def] >>
    fs[is_term_valuation_def] >>
    rw[] >>
    cheat ) >>
    need something like termsem_free_consts
    termsem_def
    instance_def

  disch_then (SUBST1_TAC o SYM) >>
  match_mp_tac termsem_consts >>
  termsem_frees
  constrain_assignment_def
*)

val old_constrain_assignment_def = Define`
  old_constrain_assignment cs f =
    λname args. case cs name args of SOME x => x | NONE => f name args`

val old_constrain_interpretation_def = Define`
  old_constrain_interpretation (tycs,tmcs) ((δ,γ):'U interpretation) =
    (old_constrain_assignment tycs δ,
     old_constrain_assignment tmcs γ)`

val old_add_constraints_thm = store_thm("old_add_constraints_thm",
  ``is_set_theory ^mem ⇒
    ∀i upd ctxt cs.
      upd updates ctxt ∧ ctxt extends init_ctxt ∧
      i models (thyof (upd::ctxt)) ∧
      (∀name args. IS_SOME (FST cs name args) ⇒
        MEM (name,LENGTH args) (types_of_upd upd) ∧
        inhabited (THE (FST cs name args)) ∧
        ∀x. MEM x (MAP FST (consts_of_upd upd)) ⇒
            IS_SOME (SND cs x args)
            (* the type of the constant should have exactly the same type
            variables as the new type hence the re-use of args here *)) ∧
      (∀name args. IS_SOME (SND cs name args) ⇒
        ∃ty. MEM (name,ty) (consts_of_upd upd) ∧
             (LENGTH (tyvars ty) = LENGTH args) ∧
             ∀τ. is_type_valuation τ ∧
                 (MAP τ (STRING_SORT (tyvars ty)) = args) ⇒
             (THE (SND cs name args)) <: typesem (old_constrain_assignment (FST cs) (FST i)) τ ty) ∧
      (∀p. MEM p (axioms_of_upd upd) ⇒
        old_constrain_interpretation cs i satisfies (sigof (upd::ctxt),[],p))
      ⇒
      (old_constrain_interpretation cs i) models (thyof (upd::ctxt))``,
  rw[] >> fs[models_def] >>
  REWRITE_TAC[CONJ_ASSOC] >>
  `theory_ok (thyof ctxt)` by metis_tac[extends_theory_ok,init_theory_ok] >>
  `∃δ γ. i =(δ,γ)` by metis_tac[pair_CASES] >>
  `∃tycs tmcs. cs =(tycs,tmcs)` by metis_tac[pair_CASES] >>
  `ALL_DISTINCT (MAP FST (type_list (upd::ctxt))) ∧
   ALL_DISTINCT (MAP FST (const_list (upd::ctxt)))` by (
    conj_tac >>
    imp_res_tac updates_ALL_DISTINCT >>
    first_x_assum match_mp_tac >>
    imp_res_tac extends_ALL_DISTINCT >>
    first_x_assum match_mp_tac >>
    EVAL_TAC ) >>
  conj_asm1_tac >- (
    fs[is_interpretation_def,is_std_interpretation_def,old_constrain_interpretation_def] >>
    simp[GSYM CONJ_ASSOC] >>
    conj_tac >- (
      fs[is_type_assignment_def,FEVERY_ALL_FLOOKUP] >> rw[] >>
      res_tac >> rw[old_constrain_assignment_def] >>
      BasicProvers.CASE_TAC >> rw[] >>
      fs[IS_SOME_EXISTS,PULL_EXISTS] >>
      res_tac >> metis_tac[] ) >>
    CONV_TAC(lift_conjunct_conv(can (match_term ``is_std_type_assignment X``))) >>
    conj_asm1_tac >- (
      fs[is_std_type_assignment_def,old_constrain_assignment_def] >>
      imp_res_tac theory_ok_sig >>
      fs[is_std_sig_def,IS_SOME_EXISTS,PULL_EXISTS] >>
      imp_res_tac ALOOKUP_MEM >>
      rw[] >> fs[ALL_DISTINCT_APPEND] >>
      BasicProvers.CASE_TAC >>
      res_tac >> fs[] >> rw[] >>
      rpt (BasicProvers.CASE_TAC >> res_tac >> fs[]) >>
      fs[MEM_MAP,EXISTS_PROD] >> metis_tac[]) >>
    conj_tac >- (
      fs[interprets_def,old_constrain_assignment_def] >> rw[] >>
      BasicProvers.CASE_TAC >>
      fs[IS_SOME_EXISTS,PULL_EXISTS] >>
      imp_res_tac theory_ok_sig >>
      fs[is_std_sig_def] >>
      imp_res_tac ALOOKUP_MEM >>
      fs[Once updates_cases] >> rw[] >> fs[] >>
      res_tac >> fs[] >> rw[] >>
      fs[MEM_MAP,EXISTS_PROD,LET_THM] >>
      metis_tac[] ) >>
    fs[is_term_assignment_def,FEVERY_ALL_FLOOKUP] >> rw[] >>
    first_x_assum(fn th => first_assum(strip_assume_tac o MATCH_MP th)) >>
    first_x_assum(fn th => first_assum(strip_assume_tac o MATCH_MP th)) >>
    rw[old_constrain_assignment_def] >>
    reverse BasicProvers.CASE_TAC >- (
      fs[IS_SOME_EXISTS,PULL_EXISTS] >>
      first_x_assum(fn th => first_assum(strip_assume_tac o MATCH_MP th)) >>
      qpat_assum`FLOOKUP X Y = Z`mp_tac >>
      simp[FLOOKUP_FUNION] >>
      BasicProvers.CASE_TAC >- (
        imp_res_tac ALOOKUP_FAILS >> fs[] ) >>
      rw[] >>
      `v = ty` by (
        fs[Once updates_cases] >> rw[] >> fs[] >>
        qmatch_assum_abbrev_tac`ALOOKUP al k = SOME v` >>
        `ALL_DISTINCT (MAP FST al)` by (
          simp[Abbr`al`,MAP_MAP_o,combinTheory.o_DEF,UNCURRY,ETA_AX] ) >>
        imp_res_tac ALOOKUP_ALL_DISTINCT_MEM >>
        fs[Abbr`al`] ) >>
      rw[] >> res_tac >> fs[old_constrain_assignment_def]) >>
    Cases_on`type_ok (tysof ctxt) v` >- (
      qmatch_abbrev_tac`a <: b` >>
      qmatch_assum_abbrev_tac`a <: c` >>
      qsuff_tac `b = c` >- rw[] >>
      unabbrev_all_tac >>
      match_mp_tac typesem_consts >>
      first_assum(match_exists_tac o concl) >> simp[] >>
      simp[type_ok_def] >> rw[FUN_EQ_THM] >>
      BasicProvers.CASE_TAC >>
      fs[IS_SOME_EXISTS,PULL_EXISTS] >> res_tac >>
      fs[Once updates_cases] >> rw[] >> fs[] >> rw[] >>
      imp_res_tac ALOOKUP_MEM >> fs[MEM_MAP,EXISTS_PROD] >>
      metis_tac[] ) >>
    qpat_assum`FLOOKUP X Y = Z`mp_tac >>
    simp[FLOOKUP_FUNION] >>
    BasicProvers.CASE_TAC >- (
      strip_tac >>
      fs[theory_ok_def] >>
      qsuff_tac`F`>-rw[]>>
      qpat_assum`¬x`mp_tac >>simp[]>>
      first_x_assum match_mp_tac >>
      simp[IN_FRANGE_FLOOKUP] >>
      metis_tac[] ) >>
    rw[] >>
    qmatch_abbrev_tac`a <: b` >>
    qmatch_assum_abbrev_tac`a <: c` >>
    qsuff_tac `b = c` >- rw[] >>
    unabbrev_all_tac >>
    fs[Once updates_cases] >> rw[] >> fs[] >- (
      rpt AP_THM_TAC >> AP_TERM_TAC >> rw[FUN_EQ_THM] ) >>
    qmatch_abbrev_tac`typesem d1 τ v = typesem δ τ v` >>
    `is_std_type_assignment d1 ∧
     is_std_type_assignment δ` by (
       reverse conj_asm2_tac >- fs[is_std_interpretation_def] >>
       simp[Abbr`d1`,GSYM old_constrain_assignment_def] ) >>
    rator_x_assum`ALOOKUP` mp_tac >> simp[] >>
    Q.PAT_ABBREV_TAC`t1 = domain (typeof pred)` >>
    Q.PAT_ABBREV_TAC`t2 = Tyapp name X` >>
    qsuff_tac`k ∈ {abs;rep} ∧ (set (tyvars v) = set (tyvars (Fun t1 t2))) ⇒
              (typesem d1 τ t1 = typesem δ τ t1) ∧
              (typesem d1 τ t2 = typesem δ τ t2)` >- (
      match_mp_tac SWAP_IMP >> strip_tac >>
      discharge_hyps >- (
        pop_assum mp_tac >> rw[] >>
        simp[tyvars_def] >>
        metis_tac[pred_setTheory.UNION_COMM] ) >>
      pop_assum mp_tac >>
      rw[] >>
      qmatch_abbrev_tac`typesem d1 τ (Fun dom rng) = typesem δ τ (Fun dom rng)` >>
      qspecl_then[`δ`,`τ`,`dom`,`rng`]mp_tac typesem_Fun >>
      qspecl_then[`d1`,`τ`,`dom`,`rng`]mp_tac typesem_Fun >>
      simp[] >> rw[]) >>
    strip_tac >>
    conj_tac >- (
      unabbrev_all_tac >>
      match_mp_tac typesem_consts >>
      qexists_tac`tysof (ctxt)` >>
      imp_res_tac proves_term_ok >>
      qpat_assum`k ∈ X`kall_tac >>
      fs[term_ok_def] >>
      conj_tac >- (
        imp_res_tac term_ok_type_ok >>
        fs[theory_ok_def] ) >>
      simp[type_ok_def] >> rw[FUN_EQ_THM] >>
      BasicProvers.CASE_TAC >>
      fs[IS_SOME_EXISTS,PULL_EXISTS] >> res_tac >>
      imp_res_tac ALOOKUP_MEM >>
      fs[MEM_MAP,EXISTS_PROD] >> metis_tac[] ) >>
    unabbrev_all_tac >>
    simp[typesem_def,MAP_MAP_o,combinTheory.o_DEF,ETA_AX] >>
    BasicProvers.CASE_TAC >>
    qsuff_tac`set (tyvars v) = set (tvars pred)` >- (
      qpat_assum`set (tyvars v) = X`kall_tac >>
      rw[] >>
      `STRING_SORT (tvars pred) = STRING_SORT (tyvars v)` by (
        `ALL_DISTINCT (tvars pred)` by simp[] >>
        `ALL_DISTINCT (tyvars v)` by simp[] >>
        `PERM (tvars pred) (tyvars v)` by (
          match_mp_tac sortingTheory.PERM_ALL_DISTINCT >>
          fs[pred_setTheory.EXTENSION] ) >>
        metis_tac[holSyntaxLibTheory.STRING_SORT_EQ] ) >>
      fs[IS_SOME_EXISTS,PULL_EXISTS,LET_THM] >>
      metis_tac[optionTheory.NOT_SOME_NONE] ) >>
    simp[tyvars_def,pred_setTheory.EXTENSION,
         holSyntaxLibTheory.MEM_FOLDR_LIST_UNION,
         MEM_MAP,PULL_EXISTS] >>
    qpat_assum`k ∈ X`kall_tac >>
    imp_res_tac proves_term_ok >> fs[term_ok_def] >>
    fs[WELLTYPED] >>
    imp_res_tac tyvars_typeof_subset_tvars >>
    fs[pred_setTheory.SUBSET_DEF,tyvars_def] >>
    metis_tac[] ) >>
  gen_tac >>
  qmatch_abbrev_tac`P ⇒ q` >>
  strip_tac >> qunabbrev_tac`q` >>
  first_x_assum(qspec_then`p`mp_tac) >>
  fs[Abbr`P`] >>
  disch_then kall_tac >>
  first_x_assum(qspec_then`p`mp_tac) >> simp[] >>
  strip_tac >>
  `term_ok (sigof ctxt) p` by fs[theory_ok_def] >>
  imp_res_tac theory_ok_sig >>
  match_mp_tac satisfies_extend >>
  map_every qexists_tac[`tysof ctxt`,`tmsof ctxt`] >>
  simp[] >>
  REWRITE_TAC[CONJ_ASSOC] >>
  conj_asm1_tac >- (
    conj_tac >>
    match_mp_tac SUBMAP_FUNION >>
    disj2_tac >>
    fs[ALL_DISTINCT_APPEND,pred_setTheory.IN_DISJOINT] >>
    metis_tac[] ) >>
  match_mp_tac satisfies_consts >>
  qexists_tac`i` >> simp[] >> fs[] >>
  simp[term_ok_def,type_ok_def] >>
  REWRITE_TAC[CONJ_ASSOC] >>
  conj_tac >- (
    rw[old_constrain_interpretation_def,old_constrain_assignment_def,FUN_EQ_THM] >>
    BasicProvers.CASE_TAC >>
    fs[IS_SOME_EXISTS,PULL_EXISTS] >> res_tac >>
    fs[ALL_DISTINCT_APPEND,MEM_MAP,EXISTS_PROD] >>
    imp_res_tac ALOOKUP_MEM >>
    metis_tac[] ) >>
  fs[satisfies_def] >> rw[] >>
  qmatch_assum_abbrev_tac`tmsof ctxt ⊑ tmsig` >>
  qmatch_assum_abbrev_tac`tysof ctxt ⊑ tysig` >>
  first_assum(
    mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO](UNDISCH extend_valuation_exists))) >>
  first_assum(fn th => disch_then (mp_tac o C MATCH_MP th)) >>
  discharge_hyps >- fs[is_interpretation_def] >> strip_tac >>
  first_x_assum(qspec_then`v'`mp_tac) >> simp[] >>
  disch_then (SUBST1_TAC o SYM) >>
  match_mp_tac EQ_TRANS >>
  qexists_tac`termsem (tmsof ctxt) (δ,γ) v' p` >>
  conj_tac >- (
    match_mp_tac termsem_frees >>
    simp[] >> rw[] >>
    first_x_assum match_mp_tac >>
    imp_res_tac term_ok_VFREE_IN >>
    fs[term_ok_def] ) >>
  metis_tac[termsem_extend])

val _ = export_theory()