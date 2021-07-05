(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(*i $Id: ConstructiveEpsilon.v 12112 2009-04-28 15:47:34Z herbelin $ i*)

(** This provides with a proof of the constructive form of definite
and indefinite descriptions for Sigma^0_1-formulas (hereafter called
"small" formulas), which infers the sigma-existence (i.e.,
[Type]-existence) of a witness to a decidable predicate over a
countable domain from the regular existence (i.e.,
[Prop]-existence). *)

(** Coq does not allow case analysis on sort [Prop] when the goal is in
not in [Prop]. Therefore, one cannot eliminate [exists n, P n] in order to
show [{n : nat | P n}]. However, one can perform a recursion on an
inductive predicate in sort [Prop] so that the returning type of the
recursion is in [Type]. This trick is described in Coq'Art book, Sect.
14.2.3 and 15.4. In particular, this trick is used in the proof of
[Fix_F] in the module Coq.Init.Wf. There, recursion is done on an
inductive predicate [Acc] and the resulting type is in [Type].

To find a witness of [P] constructively, we program the well-known
linear search algorithm that tries P on all natural numbers starting
from 0 and going up.  Such an algorithm needs a suitable termination
certificate.  We offer two ways for providing this termination
certificate: a direct one, based on an ad-hoc predicate called
[before_witness], and another one based on the predicate [Acc].
For the first one we provide explicit and short proof terms. *)

(** Based on ideas from Benjamin Werner and Jean-François Monin *)

(** Contributed by Yevgeniy Makarov and Jean-François Monin *)

(* -------------------------------------------------------------------- *)

(* Direct version *)

Require Import Arith.

Section ConstructiveIndefiniteGroundDescription_Direct.

Variable P : nat -> Prop.

Hypothesis P_dec : forall n, {P n}+{~(P n)}.


(** The termination argument is [before_witness n], which says that
any number before any witness (not necessarily the [x] of [exists x :A, P x])
makes the search eventually stops. *)

Inductive before_witness (n:nat) : Prop :=
  | stop : P n -> before_witness n
  | next : before_witness (S n) -> before_witness n.

(* Computation of the initial termination certificate *)
Fixpoint O_witness (n : nat) : before_witness n -> before_witness 0 :=
  match n return (before_witness n -> before_witness 0) with
    | 0 => fun b => b
    | S n => fun b => O_witness n (next n b)
  end.

(* Inversion of [inv_before_witness n] in a way such that the result
is structurally smaller even in the [stop] case. *)
Definition inv_before_witness :
  forall n, before_witness n -> ~(P n) -> before_witness (S n) :=
  fun n b not_p =>
    match b with
      | stop _ p => match not_p p with end
      | next _ b => b
    end.

(** Basic program *)
Fixpoint linear_search start (b : before_witness start) : nat :=
  match P_dec start with
    | left yes => start
    | right no => linear_search (S start) (inv_before_witness start b no)
  end.

(** Though proving the properties of linear_search is feasible, it is
    more convenient to work on an enriched version using the Braga method *)
(** Relational version of linear search *)
Inductive Rls : nat -> nat -> Prop :=
| Rstop : forall {found}, P found -> Rls found found
| Rnext : forall {start found}, ~(P start) -> Rls (S start) found -> Rls start found.

(** Packed With Conformity *)
Definition linear_search_pwc start (b : before_witness start) : {n : nat | Rls start n}.
  revert start b.
  refine (fix loop start b :=
     match P_dec start with
      | left yes => exist _ start _
      | right no =>
        let (n, r) := loop (S start) (inv_before_witness start b no) in
        exist _ n _
     end).
  - apply (Rstop yes).
  - apply (Rnext no r).
Defined.

(** A variant in some sense closer to linear_search
    (no deconstruction/reconstruction of the result),
    using a suitable abstraction of the postcondition *)
Definition linear_search_pwc' start (b : before_witness start) : {n : nat | Rls start n}.
  refine ((fun Q: nat -> Prop => _ : (forall y, Rls start y -> Q y) -> {n | Q n})
            (Rls start) (fun y r => r)).
  revert start b.
  refine (fix loop start b :=
    fun rq =>
      match P_dec start with
      | left yes => exist _ start _
      | right no => loop (S start) (inv_before_witness start b no) _
      end).
  - apply rq, (Rstop yes).
  - intros y r. apply rq, (Rnext no r).
Defined.

(** Rls entails P on the output *)
Theorem Rls_post : forall {start found}, Rls start found -> P found.
Proof.
  intros * rls. induction rls as [x p | x y b rls IHrls].
  - exact p.
  - exact IHrls.
Qed.

(** Rls entails minimality of the output *)
Lemma Rls_lower_bound {found start} :
  Rls start found -> forall {k}, P k -> start <= k -> found <= k.
Proof.
  induction 1 as [x p | x y no _ IH]; intros k pk greater.
  - exact greater.
  - destruct greater as [ | k greater].
    + case (no pk).
    + apply (IH _ pk), le_n_S, greater.
Qed.

(** Start at 0 *)
Definition linear_search_from_0 (e : exists n, P n) : {n:nat | Rls 0 n} :=
    let b := let (n, p) := e in O_witness n (stop n p) in
    linear_search_pwc 0 b.

(** Main definitions *)
Definition constructive_indefinite_ground_description_nat :
  (exists n, P n) -> {n:nat | P n}.
Proof.
  intro e; destruct (linear_search_from_0 e) as [found r]; exists found.
  apply (Rls_post r).
Defined.

Definition epsilon_smallest :
  (exists n : nat, P n) -> { n : nat | P n /\ forall k, P k -> n <= k }.
Proof.
  intro e; destruct (linear_search_from_0 e) as [found r]; exists found.
  split.
  - apply (Rls_post r).
  - intros k pk. apply (Rls_lower_bound r pk), le_0_n.
Defined.

(** NB. The previous version used a negative formulation:
    [forall k, k < n -> ~P k]
    Lemmas [le_not_lt] and [lt_not_le] can help if needed. *)

End ConstructiveIndefiniteGroundDescription_Direct.

(************************************************************************)

(* Version using the predicate [Acc] *)

Section ConstructiveIndefiniteGroundDescription_Acc.

Variable P : nat -> Prop.

Hypothesis P_decidable : forall n : nat, {P n} + {~ P n}.

(** The predicate [Acc] delineates elements that are accessible via a
given relation [R]. An element is accessible if there are no infinite
[R]-descending chains starting from it.

To use [Fix_F], we define a relation R and prove that if [exists n, P n]
then 0 is accessible with respect to R. Then, by induction on the
definition of [Acc R 0], we show [{n : nat | P n}].

The relation [R] describes the connection between the two successive
numbers we try. Namely, [y] is [R]-less then [x] if we try [y] after
[x], i.e., [y = S x] and [P x] is false. Then the absence of an
infinite [R]-descending chain from 0 is equivalent to the termination
of our searching algorithm. *)

Let R (x y : nat) : Prop := x = S y /\ ~ P y.

Local Notation acc x := (Acc R x).

Lemma P_implies_acc : forall x : nat, P x -> acc x.
Proof.
intros x H. constructor.
intros y [_ not_Px]. absurd (P x); assumption.
Qed.

Lemma P_eventually_implies_acc : forall (x : nat) (n : nat), P (n + x) -> acc x.
Proof.
intros x n; generalize x; clear x; induction n as [|n IH]; simpl.
apply P_implies_acc.
intros x H. constructor. intros y [fxy _].
apply IH. rewrite fxy.
replace (n + S x) with (S (n + x)); auto with arith.
Defined.

Corollary P_eventually_implies_acc_ex : (exists n : nat, P n) -> acc 0.
Proof.
intros H; elim H. intros x Px. apply P_eventually_implies_acc with (n := x).
replace (x + 0) with x; auto with arith.
Defined.

(** In the following statement, we use the trick with recursion on
[Acc]. This is also where decidability of [P] is used. *)

Theorem acc_implies_P_eventually : acc 0 -> {n : nat | P n}.
Proof.
intros Acc_0. pattern 0. apply Fix_F with (R := R); [| assumption].
clear Acc_0; intros x IH.
destruct (P_decidable x) as [Px | not_Px].
exists x; simpl; assumption.
set (y := S x).
assert (Ryx : R y x). unfold R; split; auto.
destruct (IH y Ryx) as [n Hn].
exists n; assumption.
Defined.

Theorem constructive_indefinite_ground_description_nat_Acc :
  (exists n : nat, P n) -> {n : nat | P n}.
Proof.
intros H; apply acc_implies_P_eventually.
apply P_eventually_implies_acc_ex; assumption.
Defined.

End ConstructiveIndefiniteGroundDescription_Acc.

(************************************************************************)

Section ConstructiveGroundEpsilon_nat.

Variable P : nat -> Prop.

Hypothesis P_decidable : forall x : nat, {P x} + {~ P x}.

Definition constructive_ground_epsilon_nat (E : exists n : nat, P n) : nat
  := proj1_sig (constructive_indefinite_ground_description_nat P P_decidable E).

Definition constructive_ground_epsilon_spec_nat (E : (exists n, P n)) : P (constructive_ground_epsilon_nat E)
  := proj2_sig (constructive_indefinite_ground_description_nat P P_decidable E).

End ConstructiveGroundEpsilon_nat.

(************************************************************************)

Section ConstructiveGroundEpsilon.

(** For the current purpose, we say that a set [A] is countable if
there are functions [f : A -> nat] and [g : nat -> A] such that [g] is
a left inverse of [f]. *)

Variable A : Type.
Variable f : A -> nat.
Variable g : nat -> A.

Hypothesis gof_eq_id : forall x : A, g (f x) = x.

Variable P : A -> Prop.

Hypothesis P_decidable : forall x : A, {P x} + {~ P x}.

Definition P' (x : nat) : Prop := P (g x).

Lemma P'_decidable : forall n : nat, {P' n} + {~ P' n}.
Proof.
intro n; unfold P'; destruct (P_decidable (g n)); auto.
Defined.

Lemma constructive_indefinite_ground_description : (exists x : A, P x) -> {x : A | P x}.
Proof.
intro H. assert (H1 : exists n : nat, P' n).
destruct H as [x Hx]. exists (f x); unfold P'. rewrite gof_eq_id; assumption.
apply (constructive_indefinite_ground_description_nat P' P'_decidable)  in H1.
destruct H1 as [n Hn]. exists (g n); unfold P' in Hn; assumption.
Defined.

Lemma constructive_definite_ground_description : (exists! x : A, P x) -> {x : A | P x}.
Proof.
  intros; apply constructive_indefinite_ground_description; firstorder.
Defined.

Definition constructive_ground_epsilon (E : exists x : A, P x) : A
  := proj1_sig (constructive_indefinite_ground_description E).

Definition constructive_ground_epsilon_spec (E : (exists x, P x)) : P (constructive_ground_epsilon E)
  := proj2_sig (constructive_indefinite_ground_description E).

End ConstructiveGroundEpsilon.

(* begin hide *)
(* Compatibility: the qualificative "ground" was absent from the initial
names of the results in this file but this had introduced confusion
with the similarly named statement in Description.v *)
Notation constructive_indefinite_description_nat :=
  constructive_indefinite_ground_description_nat (only parsing).
Notation constructive_epsilon_spec_nat :=
  constructive_ground_epsilon_spec_nat (only parsing).
Notation constructive_epsilon_nat :=
  constructive_ground_epsilon_nat (only parsing).
Notation constructive_indefinite_description :=
  constructive_indefinite_ground_description (only parsing).
Notation constructive_definite_description :=
  constructive_definite_ground_description (only parsing).
Notation constructive_epsilon_spec :=
  constructive_ground_epsilon_spec (only parsing).
Notation constructive_epsilon :=
  constructive_ground_epsilon (only parsing).
(* end hide *)
