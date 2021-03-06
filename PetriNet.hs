{-# LANGUAGE GADTs #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DataKinds, TypeSynonymInstances, TypeFamilies, TypeOperators #-}
{-# LANGUAGE UndecidableInstances, FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses,FunctionalDependencies #-}

module PetriNet where

import qualified Data.Set as Set
import Data.Maybe
import qualified Data.Graph as Gr

data Nat = Z | S Nat deriving Read

convert :: Int -> Nat
convert x
          | x <= 0 = Z
          | otherwise = S (convert (x-1))

type family   Plus (n :: Nat) (m :: Nat) :: Nat
type instance Plus Z m = m
type instance Plus (S n) m = S (Plus n m)

natPlus :: Nat -> Nat -> Nat
natPlus Z m = m
natPlus (S n) m = S $ natPlus n m

-- A List of length 'n' holding values of type 'a'
data List n a where
    Nil  :: List Z a
    Cons :: a -> List m a -> List (S m) a

data SNat n where
  SZ :: SNat Z
  SS :: SNat n -> SNat (S n)

instance Show (SNat n) where
  show SZ = "SZ"
  show (SS x) = "SS " ++ (show x)

-- make a vector of length n filled with same things
myReplicate :: SNat n -> a -> List n a
myReplicate SZ     _ = Nil
myReplicate (SS n) a = Cons a (myReplicate n a)

sumNat2 :: SNat n -> SNat m -> SNat (Plus n m)
sumNat2 SZ x = x
sumNat2 (SS x) y = SS (sumNat2 x y)

-- shorthand for commonly used SNat's
sNatZero = SZ
sNatOne = SS sNatZero
sNatTwo = SS sNatOne
sNatThree = SS sNatTwo
sNatFour = SS sNatThree
sNatFive = SS sNatFour
sNatSix = SS sNatFive
sNatSeven = SS sNatSix

-- Just for visualization (a better instance would work with read)
instance Show a => Show (List n a) where
    show Nil = "Nil"
    show (Cons x xs) = show x ++ "-" ++ show xs

instance (Eq a) => Eq (List n a) where
    (==) Nil Nil = True
    (==) (Cons x xs) (Cons y ys) = ((x==y) && (xs==ys))
instance Ord a => Ord (List n a) where
    (<=) Nil Nil = True
    (<=) (Cons x xs) (Cons y ys)
                                 | x==y = (xs <= ys)
                                 | otherwise=(x <= y)

--do the function f on the list of a's and b's to get a list of c's
g :: (a -> b -> c) -> List n a -> List n b -> List n c
g f (Cons x xs) (Cons y ys) = Cons (f x y) $ g f xs ys
g f Nil Nil = Nil

g0 :: (a -> b) -> List n a -> List n b
g0 f (Cons x xs) = Cons (f x) (g0 f xs)
g0 _ Nil = Nil

-- adding vectors of length n
listAdd :: (Num a) => List n a -> List n a -> List n a
listAdd = g (\x y -> x+y)
--subtracting vectors of length n
listSub :: (Num a) => List n a -> List n a -> List n a
listSub = g (\x y -> x-y)
--cumulative sum
listSum :: (Num a) => List n a -> a
listSum Nil = 0
listSum (Cons x xs) = x + (listSum xs)
--cumulative product
listProd :: (Num a) => List n a -> a
listProd Nil = 1
listProd (Cons x xs) = x * (listProd xs)
-- and of all the booleans in this list
andAll :: List n Bool -> Bool
andAll Nil = True
andAll (Cons x xs) = x && (andAll xs) 
-- are all the entries of this vector nonnegative
allPositive :: (Num a,Ord a) => List n a -> Bool
allPositive Nil = True
allPositive (Cons x xs) = (x>=0) && allPositive xs
-- extract the m'th element of the list, if m<0 or m too big then outputs Nothing
getElement :: Int -> List n a -> Maybe a
getElement 0 (Cons x _) = Just x
getElement m (Cons x xs) = getElement (m-1) xs
getElement _ _ = Nothing
--keepSelected
desiredLength :: List t Bool -> Nat
desiredLength Nil = Z
desiredLength (Cons False xs) = desiredLength xs
desiredLength (Cons True xs) = S $ desiredLength xs
keepSelected :: SNat t2 -> List t Bool -> List t a -> List t2 a
keepSelected SZ Nil Nil = Nil
keepSelected (SS z) (Cons True xs) (Cons y ys) = Cons y (keepSelected z xs ys)
keepSelected z (Cons False xs) (Cons y ys) = keepSelected z xs ys
keepSelected _ _ _ = error "not correct length"
--find a selected a
findSelected :: (Eq a) => List t a -> a -> Maybe Int
findSelected Nil _ = Nothing
findSelected (Cons x xs) y
                           | x==y = Just 0
                           | isNothing z = Nothing
                           | otherwise = Just (1+fromJust z) where z=findSelected xs y
--different version of keep selected
keepSelected2 :: List t a -> (a -> Bool) -> [a]
keepSelected2 Nil _ = []
keepSelected2 (Cons x xs) selector
                                  | selector x = x:theRest
                                  | otherwise = theRest
                                  where theRest=(keepSelected2 xs selector)

appendLists :: List n a -> List m a -> List (Plus n m) a
appendLists (Cons x xs) ys = Cons x (appendLists xs ys)
appendLists Nil ys = ys
-- 0 through n
makeUpToT :: SNat t -> List t Int
makeUpToT SZ = Nil
makeUpToT (SS z) = Cons 0 (g0 (+1) (makeUpToT z))

removeDuplicates :: Eq a => [a] -> [a]
removeDuplicates = rdHelper []
    where rdHelper seen [] = seen
          rdHelper seen (x:xs)
              | x `elem` seen = rdHelper seen xs
              | otherwise = rdHelper (seen ++ [x]) xs

type Matrix n m a = List n (List m a)
-- same as g but on something that is n by m instead of just a 1 dimensional list
g2 :: (a -> b -> c) -> (Matrix n m a) -> (Matrix n m b) -> (Matrix n m c)
g2 f = g (g f)

myReplicate2D :: SNat n -> SNat m -> a -> Matrix n m a
myReplicate2D myN myM x = myReplicate myN (myReplicate myM x)

horizantalBlocks :: Matrix n m1 a -> Matrix n m2 a -> Matrix n (Plus m1 m2) a
horizantalBlocks mat1 mat2 = g appendLists mat1 mat2
verticalBlocks :: Matrix n1 m a -> Matrix n2 m a -> Matrix (Plus n1 n2) m a
verticalBlocks mat1 mat2 = appendLists mat1 mat2
blockDiagonal :: (Num a) => SNat n1 -> SNat m1 -> SNat n2 -> SNat m2 -> Matrix n1 m1 a -> Matrix n2 m2 a -> Matrix (Plus n1 n2) (Plus m1 m2) a
blockDiagonal myN1 myM1 myN2 myM2 mat1 mat2 = verticalBlocks (horizantalBlocks mat1 (myReplicate2D myN1 myM2 0)) (horizantalBlocks (myReplicate2D myN2 myM1 0) mat2)

transposeVec :: List m a -> Matrix m (S Z) a
transposeVec Nil = Nil
transposeVec (Cons x xs) = verticalBlocks (Cons (Cons x Nil) Nil) (transposeVec xs)

transpose :: SNat m -> SNat n -> Matrix n m a -> Matrix m n a
transpose sM _ Nil = myReplicate sM Nil
transpose sM (SS sN) (Cons x xs) = horizantalBlocks (transposeVec x) (transpose sM sN xs)

data Bounds n = List n Int :< List n Int deriving Eq

appendBounds :: Bounds n -> Bounds m -> Bounds (Plus n m)
appendBounds (lb1 :< ub1) (lb2 :< ub2) = (appendLists lb1 lb2) :< (appendLists ub1 ub2)

-- all occ_i should be between l_i and u_i for the list of occupationNumbers, and lists of lower and upper Bounds
withinBounds :: List numPlaces Int -> Bounds numPlaces -> Bool
withinBounds occupationNumbers (lowerBounds :< upperBounds) = andAll (g (\x y -> x<=y) lowerBounds occupationNumbers) && andAll (g (\x y -> x<=y) occupationNumbers upperBounds)

data PetriNet n t = PetriNet{wPlus :: Matrix t n Int, wMinus :: Matrix t n Int, occupationNumbers :: List n Int, placeCapacities :: Bounds n,placeNames :: List n [Char],transitionNames :: List t [Char]} deriving Eq

myShow :: PetriNet n t -> [Char]
myShow petri1 = (show $ wPlus petri1) ++ ("\n") ++ (show $ wMinus petri1) ++ ("\n") ++ (show $ occupationNumbers petri1) ++ "\n" ++ (show $ placeNames petri1) ++ "\n" ++ (show $ transitionNames petri1)

instance Show (PetriNet n t) where
   show petri1 = myShow petri1

-- a transition is fired in two steps, one is the input into the transition state
-- the second is the output from intermediate transition state into the outputs
-- this is done to avoid the possibility of needing the outputs of the transition to be able to fire
-- like X -> 2X but starting with 0 X. Could fire if had 0X -> -1 X -> 1X capability but that would require integers instead of natural numbers
-- when invalid get Nothing by using the Maybe monad here
fireTransition :: Maybe (PetriNet n t) -> Int -> Maybe (PetriNet n t)
fireTransitionPart1 :: Maybe (PetriNet n t) -> Int -> Maybe (PetriNet n t)
fireTransitionPart2 :: Maybe (PetriNet n t) -> Int -> Maybe (PetriNet n t)

fireTransitionPart1 Nothing _ = Nothing
fireTransitionPart1 (Just myPetriNet) myTransition
                                       | withinBounds (occupationNumbers newPetriNet) (placeCapacities newPetriNet)= Just newPetriNet
                                       | otherwise = Nothing
                                       where newPetriNet=PetriNet{wPlus=wPlus myPetriNet,wMinus=wMinus myPetriNet,
                                       occupationNumbers = listSub (occupationNumbers myPetriNet) (fromJust $ getElement myTransition (wMinus myPetriNet)),
                                       placeCapacities=placeCapacities myPetriNet,placeNames=placeNames myPetriNet,
                                       transitionNames=transitionNames myPetriNet}
fireTransitionPart2 myPetriNet myTransition
                                       | isNothing myPetriNet = Nothing
                                       | withinBounds (occupationNumbers newPetriNet) (placeCapacities newPetriNet)= Just newPetriNet
                                       | otherwise = Nothing
                                       where newPetriNet=PetriNet{wPlus=wPlus $ fromJust myPetriNet,wMinus=wMinus $ fromJust myPetriNet,
                                       occupationNumbers = listAdd (occupationNumbers $ fromJust myPetriNet) (fromJust $ getElement myTransition $ wPlus $ fromJust myPetriNet),
                                       placeCapacities = placeCapacities $ fromJust myPetriNet,placeNames = placeNames $ fromJust myPetriNet,
                                       transitionNames = transitionNames $ fromJust myPetriNet}
fireTransition myPetriNet myTransition = fireTransitionPart2 (fireTransitionPart1 myPetriNet myTransition) myTransition

fireTransitionByName :: Maybe (PetriNet n t) -> [Char] -> Maybe (PetriNet n t)
fireTransitionByName Nothing _ = Nothing
fireTransitionByName myPetriNet name
                                    | isNothing z = Nothing
                                    | otherwise = fireTransition myPetriNet (fromJust z) where z = findSelected (transitionNames $ fromJust myPetriNet) name

findCatalysts :: SNat n -> SNat t -> PetriNet n t -> List n Bool
findCatalysts sN sT petri = g (\x y -> x==y) (transpose sN sT $ wPlus petri) (transpose sN sT $ wMinus petri)

wPlusT1Ex = (Cons 0 $ Cons 1 $ Cons 1 $ Cons 0 Nil)
wPlusT2Ex = (Cons 1 $ Cons 0 $ Cons 0 $ Cons 1 Nil)
wPlusEx = Cons wPlusT1Ex (Cons wPlusT2Ex Nil)
wMinusT1Ex = (Cons 1 $ Cons 0 $ Cons 0 $ Cons 0 Nil)
wMinusT2Ex = (Cons 0 $ Cons 1 $ Cons 1 $ Cons 0 Nil)
wMinusEx = Cons wMinusT1Ex (Cons wMinusT2Ex Nil)
occupationNumbersEx = Cons 1 $ Cons 0 $ Cons 2 $ Cons 1 Nil
boundsEx = (Cons 0 $ Cons 0 $ Cons 0 $ Cons 0 Nil) :< (Cons 10 $ Cons 10 $ Cons 10 $ Cons 10 Nil)
placeNamesEx0 = Cons "A0" $ Cons "B0" $ Cons "C0" $ Cons "D0" Nil
placeNamesEx1 = Cons "A1" $ Cons "B1" $ Cons "C1" $ Cons "D1" Nil
transitionNamesEx0 = Cons "A0->B0C0" $ Cons "B0C0->A0D0" Nil
transitionNamesEx1 = Cons "A1->B1C1" $ Cons "B1C1->A1D1" Nil
petriNetEx0 = PetriNet{wPlus=wPlusEx,wMinus=wMinusEx,occupationNumbers=occupationNumbersEx,placeCapacities=boundsEx,placeNames=placeNamesEx0,transitionNames=transitionNamesEx0}
petriNetEx1 = PetriNet{wPlus=wPlusEx,wMinus=wMinusEx,occupationNumbers=occupationNumbersEx,placeCapacities=boundsEx,placeNames=placeNamesEx1,transitionNames=transitionNamesEx1}
-- t0 can fire but t1 cannot, so new1Ex is okay but new2Ex is Nothing
new1Ex = fireTransitionByName (Just petriNetEx1) "A1->B1C1"
new2Ex = fireTransitionByName (Just petriNetEx1) "B1C1->A1D1"
new3Ex = fireTransitionByName (Just petriNetEx1) "B0C0->A0D0"
new4Ex = fireTransitionByName (new1Ex) "A1->B1C1"
new5Ex = fireTransitionByName (new1Ex) "B1C1->A1D1"
exampleCatalysts = findCatalysts sNatFour sNatTwo petriNetEx0

fireAllTransitions :: Maybe (PetriNet n t) -> SNat t -> List t (Maybe (PetriNet n t))
fireAllTransitions startingNet sT = g0 (\x -> (fireTransition startingNet x)) (makeUpToT sT) 
neighbors :: Maybe (PetriNet n t) -> SNat t -> [Maybe (PetriNet n t)]
neighbors startingNet sT = keepSelected2 (fireAllTransitions startingNet sT) (\x -> not $ isNothing x)
neighbors2 :: Maybe (PetriNet n t) -> SNat t -> [Maybe (PetriNet n t)]
neighbors2 startingNet sT = removeDuplicates $ keepSelected2 (fireAllTransitions startingNet sT) (const True)

--using the standard ordering of vertices on a k-ary tree, makes the list of Maybe PetriNet's
-- such that the j'th child of the i'th parent is the result of firing the j'th transition from the Maybe PetriNet at i
-- max should be (1+k+\cdots k^{depth})-1 if you want to explore everything reachable in <=depth steps
parentsAndSiblingOrder k max  = tail [(div (i-1) k,i-1-(div (i-1) k)*k)| i<-[0..max]]
getAssociatedFunction :: (a -> Int -> a) -> (Int,Int) -> [a] -> a
getAssociatedFunction f (i,j) xs = f ((!! i) xs) j
fs :: Maybe (PetriNet n t) -> Int -> Int -> [[Maybe (PetriNet n t)] -> Maybe (PetriNet n t)]
fs startingNet k max = (const startingNet):[getAssociatedFunction fireTransition pair | pair <- parentsAndSiblingOrder k max]
loeb :: Functor f => f (f a -> a) -> f a
loeb x = go where go = fmap ($ go) x
getEventTree :: Maybe (PetriNet n t) -> Int -> Int -> [Maybe (PetriNet n t)]
getEventTree startingNet k max = loeb (fs startingNet k max)
getEventTree2 :: Maybe (PetriNet n t) -> Int -> Int -> [Maybe (PetriNet n t)]
getEventTree2 startingNet k depth = getEventTree startingNet k (quot (k*(k^(depth)-1)) (k-1))
removeNothings :: [Maybe a] -> [a]
removeNothings xs = map fromJust $ filter (not . isNothing) xs

--given the total list of markings that we will ever bother to see including Nothing as a sink vertex
--this graph has arrows for there exists a transition taking you from one to the other
createGraph :: (Ord key) => SNat t -> [Maybe (PetriNet n t)] -> (Maybe (PetriNet n t) -> key) -> (Gr.Graph, Gr.Vertex -> ((Maybe (PetriNet n t)), key, [key]), key -> Maybe Gr.Vertex)
createGraph sT startingNets f = Gr.graphFromEdges [(currentP,f currentP,[f targetP | targetP <- neighbors2 currentP sT]) | currentP <- startingNets]
createGraph2 sT startingNets = createGraph sT startingNets (fmap (\x -> occupationNumbers x))
createGraph3 sT startingNet k max = createGraph2 sT (mappend [Nothing] xs) where xs=(filter (not . isNothing) (getEventTree startingNet k max))
createGraph4 sT startingNet k depth = createGraph2 sT (mappend [Nothing] xs) where xs=(filter (not . isNothing) (getEventTree2 startingNet k depth))

blockEx = blockDiagonal sNatTwo sNatFour sNatTwo sNatFour wPlusEx wMinusEx

disjointUnion :: SNat n1 -> SNat t1 -> SNat n2 -> SNat t2 -> (PetriNet n1 t1) -> (PetriNet n2 t2) -> (PetriNet (Plus n1 n2) (Plus t1 t2))
disjointUnion myN1 myT1 myN2 myT2 petri1 petri2 = PetriNet{wPlus = blockDiagonal myT1 myN1 myT2 myN2 (wPlus petri1) (wPlus petri2),
                                                           wMinus = blockDiagonal myT1 myN1 myT2 myN2 (wMinus petri1) (wMinus petri2),
                                                           occupationNumbers = appendLists (occupationNumbers petri1) (occupationNumbers petri2),
                                                           placeCapacities = appendBounds (placeCapacities petri1) (placeCapacities petri2),
                                                           placeNames = appendLists (placeNames petri1) (placeNames petri2),
                                                           transitionNames = appendLists (transitionNames petri1) (transitionNames petri2)}

-- first input has True at the places that will get collapsed into one
-- so all but the first of them should not be kept
-- everything else gets marked True for keepSelected
toKeep :: List n Bool -> Bool -> List n Bool
toKeep Nil _ = Nil
toKeep (Cons True xs) False = Cons True (toKeep xs True)
toKeep (Cons True xs) True = Cons False (toKeep xs True)
toKeep (Cons False xs) alreadyFound = Cons True (toKeep xs alreadyFound)

-- f will either be the sum of numbers so \x y -> x+y
-- or intersection of bounds which uses max or min
collapseManyPlacesHelper0 :: a -> (a -> a -> a) -> List n1 a -> List n1 Bool -> a
collapseManyPlacesHelper0 defaultVal _ _ Nil = defaultVal
collapseManyPlacesHelper0 defaultVal f (Cons _ xs) (Cons False ys) = collapseManyPlacesHelper0 defaultVal f xs ys
collapseManyPlacesHelper0 defaultVal f (Cons x xs) (Cons True ys) = f x (collapseManyPlacesHelper0 defaultVal f xs ys)

-- replaces all the places that have True in the second input list by the third input replaceValue
collapseManyPlacesHelper1 :: List n1 a -> List n1 Bool -> a -> List n1 a
collapseManyPlacesHelper1 Nil Nil replaceValue = Nil
collapseManyPlacesHelper1 (Cons x xs) (Cons True ys) replaceValue = Cons replaceValue (collapseManyPlacesHelper1 xs ys replaceValue)
collapseManyPlacesHelper1 (Cons x xs) (Cons False ys) replaceValue = Cons x (collapseManyPlacesHelper1 xs ys replaceValue)

-- find the sum/max/min as appropriate, replace all the ones that get collapsed by that value, then remove the extraneous places
collapseManyPlacesHelper2 :: a -> (a -> a -> a) -> List n1 Bool -> SNat n2  -> List n1 a -> List n2 a
collapseManyPlacesHelper2 defaultVal f ys myN xs = keepSelected myN keepSelectedHelper (collapseManyPlacesHelper1 xs ys replaceValue) where
                                        replaceValue = collapseManyPlacesHelper0 defaultVal f xs ys
                                        keepSelectedHelper = toKeep ys False

collapseManyPlacesHelper3 :: (Num a) => List n1 Bool -> SNat n2 -> List n1 a -> List n2 a
collapseManyPlacesHelper3 = collapseManyPlacesHelper2 0 (\x y -> x+y)

collapseManyPlacesHelper4 :: (Num a) => List n1 Bool -> SNat n2 -> Matrix t1 n1 a -> Matrix t1 n2 a
collapseManyPlacesHelper4 ys myN = g0 (\xs -> collapseManyPlacesHelper3 ys myN xs)

collapseManyPlacesHelper5 :: List n1 Bool -> SNat n2 -> List n1 Int -> List n2 Int
collapseManyPlacesHelper5 = collapseManyPlacesHelper2 (minBound::Int) (\x y -> max x y)

collapseManyPlacesHelper6 :: List n1 Bool -> SNat n2 -> List n1 Int -> List n2 Int
collapseManyPlacesHelper6 = collapseManyPlacesHelper2 (maxBound::Int) (\x y -> min x y)

collapseManyPlacesHelper8 :: List n1 Bool -> SNat n2 -> List n1 [Char] -> List n2 [Char]
collapseManyPlacesHelper8 = (collapseManyPlacesHelper2 [] (\x y -> x ++ "=" ++ y))

removeLastEquals :: [Char] -> [Char]
removeLastEquals []=[]
removeLastEquals ['=']=[]
removeLastEquals [x] = [x]
removeLastEquals (x:xs)=x:(removeLastEquals xs)

collapseManyPlacesHelper7 :: List n1 Bool -> SNat n2 -> Bounds n1 -> Bounds n2
collapseManyPlacesHelper7 ys myN (lb :< ub) = (collapseManyPlacesHelper5 ys myN lb) :< (collapseManyPlacesHelper6 ys myN ub)

collapseManyPlaces :: (PetriNet n1 t1) -> List n1 Bool -> SNat n2 -> PetriNet n2 t1
collapseManyPlaces startingNet toCollapse myN = PetriNet{wPlus = collapseManyPlacesHelper4 toCollapse myN (wPlus startingNet),
                                                         wMinus = collapseManyPlacesHelper4 toCollapse myN (wMinus startingNet),
                                                         occupationNumbers = collapseManyPlacesHelper3 toCollapse myN (occupationNumbers startingNet),
                                                         placeCapacities = collapseManyPlacesHelper7 toCollapse myN (placeCapacities startingNet),
                                                         placeNames = g0 removeLastEquals $ collapseManyPlacesHelper8 toCollapse myN (placeNames startingNet),
                                                         transitionNames=transitionNames startingNet}

petriNetEx2 = disjointUnion sNatFour sNatTwo sNatFour sNatTwo petriNetEx0 petriNetEx1

whichToCollapse = Cons True $ Cons False $ Cons False $ Cons False $ Cons True $ Cons True $ Cons False $ Cons False Nil
petriNetEx3 = collapseManyPlaces petriNetEx2 whichToCollapse sNatSix

-- 
class Kripke a b | a -> b where
    predicates :: a -> List b Bool

-- only one of the following can be used because of functional dependencies
instance Kripke (PetriNet n t) Z where
    predicates petri = Nil
--instance Kripke (PetriNet n t) (S Z) where
--    predicates petri = Cons True Nil

instance ((Kripke a nP),(Kripke b nQ),(nR ~ (Plus nP nQ))) => Kripke (a,b) nR where
   predicates (x,y) = appendLists (predicates x) (predicates y)

--test case to see if above works, yes
instance Kripke Int (S(S(Z))) where 
   predicates x = Cons (x>0) $ Cons (x<10) Nil
testKripke=predicates ((5,5)::(Int,Int))
   
kripkeWord :: Kripke a nP => [a] -> [List nP Bool]
kripkeWord stateSequence = [predicates state | state <- stateSequence]

-- store a prefix tree, where the paths are prefixes. The information stored at the vertices is
-- the bounds on the incoming occupationNumbers if that firing sequence is to be sensible and the change in occupationNumbers
-- if that firing sequence were executed
--data Leaf numPlaces = Leaf {myBounds::Bounds numPlaces,overallChange::List numPlaces Int,firable :: Bool}
--data InternalNode numPlaces = InternalNode {myBounds::Bounds numPlaces,overallChange::List numPlaces Int,firable::Bool}
--data MyPrefixTree numPlaces numTransitions = Leaf numPlaces | (InternalNode numPlaces,List numTransitions (MyPrefixTree numPlaces numTransitions))

-- x'th child in the trie where 0<=x<numTransitions if this is not possible because x is outside this range
-- or if trying to do children of a leaf, then gives Nothing
--subTrie :: Int -> MyPrefixTree numPlaces numTransitions -> Maybe MyPrefixTree numPlaces numTransitions
--subTrie _ Leaf{myBounds=_} = Nothing
--subTrie x (_,ls) = getElement x ls

--go to the vertex of the trie and extract it's data. Nothing if failure because said vertex does not exist.
--getBoundsWord :: Maybe (MyPrefixTree numPlaces numTransitions) -> [Int] -> Maybe (Bounds numPlaces)
--getBoundsWord (Just Leaf{myBounds=x,overallChange=_,firable=_}) [] = Just x
--getBoundsWord (Just Leaf{myBounds=_,overallChange=_,firable=_}) _ = Nothing
--getBoundsWord (Just (InternalNode{myBounds=x,overallChange=_,firable=_},_)) [] = Just x
--getBoundsWord (Just (_,y)) x:xs = getBoundsWord (subTrie x y) 
--getOverallChangeWord :: Maybe (MyPrefixTree numPlaces numTransitions) -> [Int] -> Maybe (List numPlaces Int)
--getOverallChangeWord (Just Leaf{myBounds=_,overallChange=x,,firable=_}) [] = Just x
--getOverallChangeWord (Just Leaf{myBounds=_,overallChange=_,firable=_}) _ = Nothing
--getOverallChangeWord (Just (InternalNode{myBounds=_,overallChange=x,firable=_},_)) [] = Just x
--getOverallChangeWord (Just (_,y)) x:xs = getBoundsWord (subTrie x y) 
--getFirable :: Maybe (MyPrefixTree numPlaces numTransitions) -> [Int] -> Maybe Bool
--getFirable (Just Leaf{myBounds=_,overallChange=_,firable=x}) [] = Just x
--getFirable (Just Leaf{myBounds=_,overallChange=_,firable=_}) _ = Nothing
--getFirable (Just (InternalNode{myBounds=_,overallChange=_,firable=x},_)) [] = Just x
--getFirable (Just (_,y)) x:xs = getBoundsWord (subTrie x y) 

data ChemicalRxnNetwork n t = ChemicalRxnNetwork{inputs :: Matrix t n Int, 
                                                 outputs :: Matrix t n Int, concentrations :: List n Double, 
                                                 rateConstants :: List t Double, moleculeNames :: List n [Char]}

disjointUnionRxn :: SNat n1 -> SNat t1 -> SNat n2 -> SNat t2 -> (ChemicalRxnNetwork n1 t1) -> (ChemicalRxnNetwork n2 t2) -> (ChemicalRxnNetwork (Plus n1 n2) (Plus t1 t2))
disjointUnionRxn myN1 myT1 myN2 myT2 rxnNet1 rxnNet2 = ChemicalRxnNetwork{inputs = blockDiagonal myT1 myN1 myT2 myN2 (inputs rxnNet1) (inputs rxnNet2),
                                                           outputs = blockDiagonal myT1 myN1 myT2 myN2 (outputs rxnNet1) (outputs rxnNet2),
                                                           concentrations = appendLists (concentrations rxnNet1) (concentrations rxnNet2),
                                                           rateConstants = appendLists (rateConstants rxnNet1) (rateConstants rxnNet2),
                                                           moleculeNames = appendLists (moleculeNames rxnNet1) (moleculeNames rxnNet2)}

-- problem adding concentrations when collapsing rather than weighted averaging them
collapseManyPlacesRxn :: (ChemicalRxnNetwork n1 t1) -> List n1 Bool -> SNat n2 -> ChemicalRxnNetwork n2 t1
collapseManyPlacesRxn rxnNet toCollapse myN = ChemicalRxnNetwork{inputs = collapseManyPlacesHelper4 toCollapse myN (inputs rxnNet),
                                                         outputs = collapseManyPlacesHelper4 toCollapse myN (outputs rxnNet),
                                                         concentrations = collapseManyPlacesHelper3 toCollapse myN (concentrations rxnNet),
                                                         rateConstants = (rateConstants rxnNet),
                                                         moleculeNames = collapseManyPlacesHelper8 toCollapse myN (moleculeNames rxnNet)}

singleRxnRateEq :: List n Int -> List n Int -> Double -> List n Double -> List n Double
singleRxnRateEq myIn myOut rateConstant concentrations = g0 (\x -> (fromIntegral x)*rateConstant*helper) myOut where
                                                                helper = (listProd (g (\c i -> c^i) concentrations myIn))
multipleRxnRateEq :: SNat n -> Matrix t n Int -> Matrix t n Int -> List t Double -> List n Double -> List n Double
multipleRxnRateEq myN Nil Nil Nil _ = myReplicate myN 0.0
multipleRxnRateEq myN (Cons in1 inRest) (Cons out1 outRest) (Cons rateConstant1 rateConstantRest) concentrations = listAdd firstContrib restContrib where 
                                                                                                                   firstContrib = singleRxnRateEq in1 out1 rateConstant1 concentrations
                                                                                                                   restContrib = multipleRxnRateEq myN inRest outRest rateConstantRest concentrations
-- example with X + ATP -> XP + ADP
exampleSingleRxnRateEq = singleRxnRateEq (Cons 1 $ Cons 1 $ Cons 0 $ Cons 0 Nil) (Cons 0 $ Cons 0 $ Cons 1 $ Cons 1 Nil) 0.5 (Cons 0.5 $ Cons 10.0 $ Cons 0.0 $ Cons 10.0 Nil)

rateEquation :: SNat n -> ChemicalRxnNetwork n t -> List n Double
--rateEquation rxnNet = rates for each of the n molecules/complexes
rateEquation myN rxnNet = multipleRxnRateEq myN (inputs rxnNet) (outputs rxnNet) (rateConstants rxnNet) (concentrations rxnNet)
rateEquationTimeStep :: SNat n -> ChemicalRxnNetwork n t -> Double -> ChemicalRxnNetwork n t
rateEquationTimeStep myN rxnNet timeStep = ChemicalRxnNetwork{inputs=(inputs rxnNet),outputs=(outputs rxnNet),concentrations=newConc,rateConstants=(rateConstants rxnNet),moleculeNames=(moleculeNames rxnNet)} where
                                       newConc = listAdd (concentrations rxnNet) (g0 (\x -> x*timeStep) (rateEquation myN rxnNet))

-- TODO: to make or import from a linear algebra module
nullspaceInt :: Matrix t n Int -> [List n Int]
nullspaceInt _ = []
--TODO: find a way to get rid of numKept being provided. Want to just provide the rateCutoff
-- DPair(n: Nat)(List n a) is possible in Idris. Look at the docs there
conservedQuantities :: ChemicalRxnNetwork n t -> [List n Int]
conservedQuantities rxnNet = nullspaceInt $ g2 (\x y -> x-y) (inputs rxnNet) (outputs rxnNet)
whichSlowReactions :: ChemicalRxnNetwork n t -> Double -> List t Bool
whichSlowReactions rxnNet rateCutoff = g0 (\x -> x>rateCutoff) (rateConstants rxnNet)
eliminateSlowReactions :: SNat t2 -> Double -> ChemicalRxnNetwork n t -> ChemicalRxnNetwork n t2
eliminateSlowReactions numKept rateCutoff rxnNet = ChemicalRxnNetwork{inputs=newIns,outputs=newOuts,concentrations=(concentrations rxnNet),rateConstants=newRateConstants,moleculeNames=(moleculeNames rxnNet)} where
                                           selection=whichSlowReactions rxnNet rateCutoff
                                           newIns=keepSelected numKept selection (inputs rxnNet)
                                           newOuts=keepSelected numKept selection (outputs rxnNet)
                                           newRateConstants = keepSelected numKept selection (rateConstants rxnNet)
quasiconservedQuantities :: SNat t2 -> Double -> ChemicalRxnNetwork n t -> [List n Int]
quasiconservedQuantities numKept rateCutoff rxnNet = conservedQuantities $ eliminateSlowReactions numKept rateCutoff rxnNet