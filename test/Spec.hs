{-# LANGUAGE GADTs #-}
import Prelude hiding (null)
import Test.Hspec
import Test.QuickCheck
import Data.Text (Text)

import Data.JSON
import Data.Hash
import Parser.JSON


main :: IO ()
main = hspec $ do
  describe "Test that parsing - unparsing JSON is an isomorphism." $
    it "parsing after serialisation is an identity" $
      property $ \(Wrapson json) ->
                   let (textBuilder, rollingHash) = json in
                   case parseJSON $ buildJSON textBuilder of
                     Left _ -> False
                     Right json' -> hash rollingHash == hash json'


data Wrapson a where
  Wrapson :: (Show json, JSON json) => json -> Wrapson json

instance Show (Wrapson json) where
  show (Wrapson j) = show j

instance (Show json, JSON json) => Arbitrary (Wrapson json) where
  arbitrary = oneof [ genString, genNum, genBool, genNull, genArray, genObject ]

genNull, genBool, genNum, genString, genArray, genObject :: (Show json, JSON json) => Gen (Wrapson json)
genNull = return $ Wrapson null
genBool = fmap (Wrapson . bool) chooseAny
genNum = fmap (Wrapson . num) chooseAny
genString = fmap (Wrapson . str) undefined
genArray = undefined
genObject = undefined
