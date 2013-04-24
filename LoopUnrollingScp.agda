--
-- Simple supercompiler using loop unrolling
--

module LoopUnrollingScp where

open import Data.Nat
open import Data.List
open import Data.Bool
open import Data.Empty
open import Data.Maybe
open import Data.Product
  hiding (map)
open import Data.Sum

open import Function
open import Function.Equality
  using (_⟨$⟩_; module Π)
open import Function.Equivalence as Equiv
  using (module Equivalence; _⇔_; equivalence)

open import Relation.Nullary
open import Relation.Nullary.Decidable
  using (⌊_⌋)

open import Relation.Binary.PropositionalEquality as P
  using (_≡_; _≢_; refl; trans; cong; subst; inspect; module ≡-Reasoning)
  renaming ([_] to [_]ⁱ)

import Function.Related as Related

open import Util
open import ExpLang
open import ImpLang
open import LoopUnrolling
open import HomEmb
open import SimpExpAsFOT

--
-- Giving a formal proof of Kruskal's theorem
-- is beyond the scope of the current work,
-- so we just postulate it.
--

postulate
  Kruskal : {V F : Set} (s : Sequence (FOTerm V F)) →
    ∃₂ λ (i j : ℕ) → i < j × (s i ⊴ s j)

-- TODO: a formal proof of `firstEmbedded-total` from `Kruskal`.

postulate
  firstEmbedded-total :
    (s : Sequence (FOTerm ⊥ TrmCons))→
      ∃₂ λ n m → firstEmbedded n s ≡ just m

--
-- A basic supercompiler
--

-- It first builds a stream of iterated unrollings of the program in KNF.
-- Then it looks for pairs of initializer expressions related by homeomorphic
-- embedding in an initial fragment of the stream (the length of this fragment
-- being specified by an input parameter -- `n`).

-- We use only initializer expressions when checking for termination,
-- because they are the only KNF part changed by the simple loop unrolling
-- used here.

-- To aid the experimentations on practical examples, there is also an input
-- option, `alwaysJust`, which can be used to force a result even if
-- no homeomorphic embedding is found in the specified initial stream segment.

--
-- Whistle
--

-- knfs⇒FOTerms

knfs⇒FOTerms : (knfs : Sequence KNFProg) → Sequence (FOTerm ⊥ TrmCons)

knfs⇒FOTerms knfs = TrmToFOTerm ∘ initExp ∘ knfs

-- whistle

whistle :
  (alwaysJust : Bool) → (n : ℕ) → (knfs : Sequence KNFProg) →
    Maybe ℕ

whistle alwaysJust n knfs =
  maybe′ just (if alwaysJust then just n else nothing)
         (firstEmbedded n (knfs⇒FOTerms knfs))

-- whistle-total

whistle-total :
  ∀ (b : Bool) (knfs : Sequence KNFProg)→
    ∃₂ λ n m → whistle b n knfs ≡ just m

whistle-total b knfs with firstEmbedded-total (knfs⇒FOTerms knfs)
... | n , m , ≡m = n , m ,
  cong (maybe just (if b then just n else nothing)) ≡m

--
-- The main loop of supercompilation
--

-- sscpCore

sscpCore :
  (alwaysJust : Bool) (unroll : KNFProg → KNFProg)
  (n : ℕ) (knf : KNFProg) → Maybe KNFProg

sscpCore alwaysJust unroll n knf =
  maybe′ (just ∘′  knfs) nothing (whistle alwaysJust n knfs)
  where
    knfs = iterate unroll knf

-- sscp

sscp : (alwaysJust : Bool) (n : ℕ) (knf : KNFProg) → Maybe KNFProg

sscp alwaysJust n knf = 
  sscpCore alwaysJust unrollToInit n knf


-- Alternatively, we define a cut-down version, which uses `normConv`
-- instead of `norm` during loop unrolling.
-- In essence, it is a simple deforestation analog of the above supercompiler.

-- unrollToInit'

unrollToInit′ : KNFProg → KNFProg

unrollToInit′ (KNF init cond body final) =
  KNF newInit cond body final
  where
    nrm = λ (t : Trm) → ntrm2trm (normConv t)
    newInit = nrm ((IfNil cond Id body) $$ init)

-- sscp′

sscp′ : (alwaysJust : Bool) (n : ℕ) (knf : KNFProg) → Maybe KNFProg

sscp′ alwaysJust n knf = 
  sscpCore alwaysJust unrollToInit′ n knf

--------------------------------------------
-- Proof of Correctness
-- (Totality and preservation of semantics)
--------------------------------------------

-- Totality is a direct consequence of totality of `firstEmbedded`.

-- sscpCore-total

sscpCore-total : ∀ b unroll knf →
  ∃₂ λ (n : ℕ) (knf′ : KNFProg) →
    sscpCore b unroll n knf ≡ just knf′

sscpCore-total b unroll knf =
  helper (whistle-total b knfs)
  where
  knfs = iterate unroll knf
  helper : ∃₂ (λ n m → whistle b n knfs ≡ just m) →
           ∃₂ (λ (n : ℕ) (knf′ : KNFProg) →
             sscpCore b unroll n knf ≡ just knf′)
  helper (n , m , ≡m) = n , knfs m , helper≡
    where
    open ≡-Reasoning
    helper≡ = begin
      sscpCore b unroll n knf
        ≡⟨ refl ⟩
      maybe′ (just ∘′  knfs) nothing (whistle b n knfs)
        ≡⟨ cong (maybe′ (just ∘′ knfs) nothing) ≡m ⟩
      maybe′ (just ∘′  knfs) nothing (just m)
        ≡⟨ refl ⟩
      just (knfs m)
      ∎  

-- sscp-total

sscp-total : ∀ b knf →
  ∃₂ λ n knf′ → sscp b n knf ≡ just knf′

sscp-total b knf with sscpCore-total b unrollToInit knf
... | n , knf′ , ≡knf′ = n , knf′ , ≡knf′


-- Preservation of semantics is established through a sequence of lemmas,
-- relying only on correctness of one-step loop unrolling.

-- condExp-unrollToInitSequence

unrolling-preserves-condExp :
  ∀ {knf} n → condExp (iterate unrollToInit knf n) ≡ condExp knf

unrolling-preserves-condExp zero =
  refl
unrolling-preserves-condExp (suc n) =
  unrolling-preserves-condExp n

-- unrolling-preserves-Pcond

unrolling-preserves-Pcond :
  ∀ {knf} n {p} (P : Trm → Set p) →
  P (condExp knf) →
  P (condExp (iterate unrollToInit knf n))

unrolling-preserves-Pcond {knf} n P =
  P (condExp knf)
    ∼⟨ subst P (P.sym $ unrolling-preserves-condExp n) ⟩
  P (condExp (iterate unrollToInit knf n))
  ∎
  where open Related.EquationalReasoning

-- ⊨KNF-unrollToInitSequence

⊨KNF-unrollToInitSequence :
  ∀ {knf v v′} n →
  strictKNF knf →
  (knf ⊨KNF v ⇓ v′) ⇔
  (iterate unrollToInit knf n ⊨KNF v ⇓ v′)

⊨KNF-unrollToInitSequence zero hs =
  Equiv.id

⊨KNF-unrollToInitSequence {knf} {v} {v′} (suc n) hs =
  knf ⊨KNF v ⇓ v′
    ∼⟨ ⊨KNF-unrollToInitSequence n hs ⟩
  iterate unrollToInit knf n ⊨KNF v ⇓ v′
    ∼⟨ unrollToInit-is-⊨KNF-unroller
       (unrolling-preserves-Pcond n strictTrm hs) ⟩
  unrollToInit (iterate unrollToInit knf n) ⊨KNF v ⇓ v′
    ≡⟨ cong (λ z → z ⊨KNF v ⇓ v′) refl ⟩
  iterate unrollToInit knf (suc n) ⊨KNF v ⇓ v′
  ∎
  where open Related.EquationalReasoning

-- evalKNF-unrollToInitSequence

evalKNF-unrollToInitSequence :
  ∀ knf v v′ n →
  strictKNF knf →
  (∃ λ (i : ℕ) → evalKNF i knf v ≡ just v′) ⇔
  (∃ λ (i′ : ℕ) → evalKNF i′ (iterate unrollToInit knf n) v ≡ just v′)

evalKNF-unrollToInitSequence knf v v′ n  hs =
  (∃ λ (i : ℕ) → evalKNF i knf v ≡ just v′)
    ∼⟨ sym $ ⊨KNF⇔evalKNF ⟩
  knf ⊨KNF v ⇓ v′
    ∼⟨ ⊨KNF-unrollToInitSequence n hs ⟩
  iterate unrollToInit knf n ⊨KNF v ⇓ v′
    ∼⟨ ⊨KNF⇔evalKNF ⟩
  (∃ λ (i′ : ℕ) → evalKNF i′ (iterate unrollToInit knf n) v ≡ just v′)
  ∎
  where open Related.EquationalReasoning

-- sscpCore-⊎

sscpCore-⊎ :
  ∀ b unroll n knf →
    (∃ λ m → sscpCore b unroll n knf ≡ just (iterate unroll knf m))
      ⊎ (sscpCore b unroll n knf ≡ nothing)

just≢nothing : ∀ {a} {A : Set a} {x : A} → (just x ∶ Maybe A) ≢ nothing 
just≢nothing = λ ()

sscpCore-⊎ b unroll n knf = helper
  where
  knfs = iterate unroll knf

  helper :
    (∃ λ m → sscpCore b unroll n knf ≡ just (knfs m))
      ⊎ sscpCore b unroll n knf ≡ nothing
  helper with whistle b n knfs
  ... | just m  = inj₁ (m , refl)
  ... | nothing = inj₂ refl

-- sscpCore-as-sequenceUnfold

sscpCore-as-sequenceUnfold :
  ∀ b unroll n knf knf′ →
    sscpCore b unroll n knf ≡ just knf′ →
    ∃ λ m → knf′ ≡ iterate unroll knf m

sscpCore-as-sequenceUnfold b unroll n knf knf′ ≡knf′
  with sscpCore-⊎ b unroll n knf
... | inj₁ (m , ≡unfold) = m , just-injective just≡just
  where
  open ≡-Reasoning
  just≡just = begin
    just knf′
      ≡⟨ P.sym ≡knf′ ⟩
    sscpCore b unroll n knf
      ≡⟨ ≡unfold ⟩
    just (iterate unroll knf m)
    ∎

... | inj₂ ≡nothing = ⊥-elim (just≢nothing just≡nothing)
  where
  open ≡-Reasoning
  just≡nothing = begin
    just knf′
      ≡⟨ P.sym ≡knf′ ⟩
    sscpCore b unroll n knf
      ≡⟨ ≡nothing ⟩
    nothing
    ∎

-- sscpCore-correct

sscpCore-correct :
  ∀ b knf knf′ n v v′ →
    strictKNF knf →
    sscpCore b unrollToInit n knf ≡ just knf′ →
      (∃ λ (i : ℕ) → evalKNF i knf v ≡ just v′) ⇔
      (∃ λ (i′ : ℕ) → evalKNF i′ knf′  v ≡ just v′)

sscpCore-correct b knf knf′ n v v′ hs hc
  with sscpCore-as-sequenceUnfold b unrollToInit n knf knf′ hc
... | m , ≡unfold =
    (∃ λ (i : ℕ) → evalKNF i knf v ≡ just v′)
      ∼⟨ evalKNF-unrollToInitSequence knf v v′ m hs ⟩
    (∃ λ (i′ : ℕ) → evalKNF i′ (iterate unrollToInit knf m) v ≡ just v′)
      ≡⟨ cong (λ z → ∃ (λ (i′ : ℕ) → evalKNF i′ z v ≡ just v′))
              (P.sym $ ≡unfold) ⟩
    (∃ λ (i′ : ℕ) → evalKNF i′ knf′ v ≡ just v′)
    ∎
    where open Related.EquationalReasoning

-- sscp-correct

sscp-correct :
  ∀ b knf knf′ n v v′ → 
    strictKNF knf →
    sscp b n knf ≡ just knf′ →
      (∃ λ (i : ℕ) → evalKNF i knf v ≡ just v′) ⇔
      (∃ λ (i′ : ℕ) → evalKNF i′ knf′  v ≡ just v′)

sscp-correct b knf knf′ n v v′ hs hc =
  sscpCore-correct b knf knf′ n v v′ hs hc

--