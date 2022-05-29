{-# LANGUAGE RankNTypes #-}
module Data.JSON.AST (
  JsonAst(..),
  TypeError(..),
  ValueError(..),
  toJSON
) where

import Control.Monad.Catch (Exception)
import Data.JSON (JSON)
import qualified Data.JSON as JSON
import Data.JSON.Repr (Repr)
import Data.Text (Text)


data JsonAst = JString Text
             | JNum Double
             | JBool Bool
             | JNull
             | JArray [JsonAst]
             | JObject [(Text, JsonAst)]
             deriving Eq

instance JSON JsonAst where
  str = JString
  num = JNum
  bool = JBool
  null = JNull
  array = JArray
  obj = JObject

toJSON :: JsonAst -> (forall j. JSON j => j)
toJSON (JString s) = JSON.str s
toJSON (JNum n) = JSON.num n
toJSON (JBool b) = JSON.bool b
toJSON JNull = JSON.null
toJSON (JArray js) = JSON.array $ map toJSON js
toJSON (JObject kvs) = JSON.obj $ map pairToJSON kvs
  where
  pairToJSON (k, v) = (k, toJSON v)

instance Show JsonAst where
  show j = show $ (toJSON j :: Repr String)

data TypeError = NotAnObject JsonAst
               | NotAList JsonAst

instance Show TypeError where
  show (NotAnObject j) = "Not an object: '" ++ show j ++ "'!"
  show (NotAList j) = "Not a list: '" ++ show j ++ "'!"

instance Exception TypeError where

data ValueError = NegativeIndex Int

instance Show ValueError where
  show (NegativeIndex i) = "Negative array index: " ++ show i ++ "!"

instance Exception ValueError
