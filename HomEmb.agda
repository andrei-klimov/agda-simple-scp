--
-- Homeomorphic embedding
--

module HomEmb where

open import Data.Nat
open import Data.Bool
open import Data.Maybe
open import Data.Empty
open import Data.Product

open import Function

open import Relation.Nullary
open import Relation.Nullary.Decidable
  using (⌊_⌋)
open import Relation.Binary.PropositionalEquality as P
  hiding (sym)

import Function.Related as Related

open import Util

-- The so-called "whistle" of our supercompiler uses
-- homeomorphic embedding and the Kruskal's tree theorem
-- to ensure termination of the process. 
-- To formulate this theorem in its general form,
-- we introduce a type of arbitrary first-order terms.

module FOTerms
  (V : Set)
  (F : Set)
  (_≟F_ : (f g : F) → Dec (f ≡ g))
  where

  data FOTerm : Set where
    FOVar  : (v : V) → FOTerm
    FOFun0 : (mf : Maybe F) → FOTerm
    FOFun2 : (mf : Maybe F) → (t₁ t₂ : FOTerm) → FOTerm

  infix 4 _≟MF_

  _≟MF_ : (mf mg : Maybe F) → Dec (mf ≡ mg)
  _≟MF_ mf mg = maybe-dec _≟F_

  -- _⊴_ - homeomorphic embedding relation

  infix 4 _⊴_

  data _⊴_ : (t₁ t₂ : FOTerm) → Set where
    ⊴-var : ∀ {u v : V} →
      FOVar u ⊴ FOVar v
    ⊴-00 : ∀ {mf : Maybe F} →
      FOFun0 mf ⊴ FOFun0 mf
    ⊴-02l : ∀ {mf mg : Maybe F} {t₁ t₂ : FOTerm} →
      FOFun0 mf ⊴ t₁ →
      FOFun0 mf ⊴ FOFun2 mg t₁ t₂
    ⊴-02r : ∀ {mf mg : Maybe F} {t₁ t₂ : FOTerm} →
      FOFun0 mf ⊴ t₂ →
      FOFun0 mf ⊴ FOFun2 mg t₁ t₂
    ⊴-22b : ∀ {mf : Maybe F} {t₁ t₂ t′₁ t′₂ : FOTerm} →
      t₁ ⊴ t′₁ → t₂ ⊴ t′₂ →
      FOFun2 mf t₁ t₂ ⊴ FOFun2 mf t′₁ t′₂
    ⊴-22l : ∀ {mf mg : Maybe F} {t₁ t₂ t′₁ t′₂ : FOTerm} →
      FOFun2 mf t₁ t₂ ⊴ t′₁ →
      FOFun2 mf t₁ t₂ ⊴ FOFun2 mg t′₁ t′₂
    ⊴-22r : ∀ {mf mg : Maybe F} {t₁ t₂ t′₁ t′₂ : FOTerm} →
      FOFun2 mf t₁ t₂ ⊴ t′₂ →
      FOFun2 mf t₁ t₂ ⊴ FOFun2 mg t′₁ t′₂

  -- _⊴_

  infix 4 _⊴?_

  _⊴?_ : (t₁ t₂ : FOTerm) → Dec (t₁ ⊴ t₂)

  FOVar v ⊴? FOVar v' =
    yes ⊴-var
  FOVar v ⊴? FOFun0 mf =
    no (λ ())
  FOVar v ⊴? FOFun2 mf t₁ t₂ =
    no (λ ())
  FOFun0 mf ⊴? FOVar v =
    no (λ ())
  FOFun0 mf ⊴? FOFun0 mg with mf ≟MF mg
  ... | yes mf≡mg rewrite mf≡mg = yes ⊴-00
  ... | no  mf≢mg = no (helper mf≢mg)
    where helper : ∀ {mf mg} → mf ≢ mg → FOFun0 mf ⊴ FOFun0 mg → ⊥
          helper n ⊴-00 = n refl
  FOFun0 mf ⊴? FOFun2 mg t₁ t₂
    with FOFun0 mf ⊴? t₁ | FOFun0 mf ⊴? t₂
  ... | yes y1 | _      = yes (⊴-02l y1)
  ... | _      | yes y2 = yes (⊴-02r y2)
  ... | no n1 | no n2   = no helper
    where helper : FOFun0 mf ⊴ FOFun2 mg t₁ t₂ → ⊥
          helper (⊴-02l y1) = n1 y1
          helper (⊴-02r y2) = n2 y2
  FOFun2 mf t₁ t₂ ⊴? FOVar v = no (λ ())
  FOFun2 mf t₁ t₂ ⊴? FOFun0 mg = no (λ ())
  FOFun2 mf t₁ t₂ ⊴? FOFun2 mg t′₁ t′₂
    with FOFun2 mf t₁ t₂ ⊴? t′₁ | FOFun2 mf t₁ t₂ ⊴? t′₂ | mf ≟MF mg 
  ... | yes y1 | _      | _ = yes (⊴-22l y1)
  ... | _      | yes y2 | _ = yes (⊴-22r y2)
  ... | no n1  | no n2  | no  mf≢mg = no (helper n1 n2 mf≢mg)
    where helper : ∀ {mf mg} →
                     (FOFun2 mf t₁ t₂ ⊴ t′₁ → ⊥) →
                     (FOFun2 mf t₁ t₂ ⊴ t′₂ → ⊥) → mf ≢ mg →
                     FOFun2 mf t₁ t₂ ⊴ FOFun2 mg t′₁ t′₂ → ⊥
          helper n1 n2 n (⊴-22b y1 y2) = n refl
          helper n1 n2 n (⊴-22l y) = n1 y
          helper n1 n2 n (⊴-22r y) = n2 y
  ... | no n1  | no n2  | yes mf≡mg
    rewrite mf≡mg with t₁ ⊴? t′₁ | t₂ ⊴? t′₂
  ... | no n11  | _       = no (helper n11)
    where helper : (t₁ ⊴ t′₁ → ⊥) →
                   FOFun2 mg t₁ t₂ ⊴ FOFun2 mg t′₁ t′₂ → ⊥
          helper n11 (⊴-22b y11 y22) = n11 y11
          helper n11 (⊴-22l y1) = n1 y1
          helper n11 (⊴-22r y2) = n2 y2
  ... | _       | no n22  = no (helper n22)
    where helper : (t₂ ⊴ t′₂ → ⊥) →
                   FOFun2 mg t₁ t₂ ⊴ FOFun2 mg t′₁ t′₂ → ⊥
          helper n22 (⊴-22b y11 y22) = n22 y22
          helper n22 (⊴-22l y1) = n1 y1
          helper n22 (⊴-22r y2) = n2 y2
  ... | yes y11 | yes y22 = yes (⊴-22b y11 y22)


  postulate
    Kruskal : (s : Sequence FOTerm) →
      ∃₂ λ (i j : ℕ) → i < j × (s i ⊴ s j)


  {-
  -- homemb

  homemb : (t1 t2 : FOTerm) → Bool
  homemb (FOVar v) (FOVar v') = true
  homemb (FOVar v) (FOFun0 mf) = false
  homemb (FOVar v) (FOFun2 mf t₁ t₂) = false
  homemb (FOFun0 mf) (FOVar v) = false
  homemb (FOFun0 mf) (FOFun0 mg) = ⌊ mf ≟MF mg ⌋
  homemb (FOFun0 mf) (FOFun2 mg t₁ t₂) =
    homemb (FOFun0 mf) t₁ ∨ homemb (FOFun0 mf) t₂
  homemb (FOFun2 mf t₁ t₂) (FOVar v) = false
  homemb (FOFun2 mf t₁ t₂) (FOFun0 mg) = false
  homemb (FOFun2 mf t₁ t₂) (FOFun2 mg t′₁ t′₂) =
    (if ⌊ mf ≟MF mg ⌋
     then homemb t₁ t′₁ ∧ homemb t₂ t′₂
     else false)
    ∨
    (homemb (FOFun2 mf t₁ t₂) t′₁ ∨ homemb (FOFun2 mf t₁ t₂) t′₂)

  postulate
    Kruskal : (s : Sequence FOTerm) →
      ∃₂ λ (i j : ℕ) → i < j × (homemb (s i) (s j) ≡ true)
  -}

--