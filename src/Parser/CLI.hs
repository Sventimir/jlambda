{-# LANGUAGE GADTs #-}
module Parser.CLI (
  CliArgs(..),
  CliError(..),
  Or(..),
  Consume(..),
  FlagSpec(..),
  parseArgs
) where

import Control.Monad.Except (ExceptT, MonadIO, runExceptT, throwError,
                             liftEither, liftIO)
import Data.Functor ((<&>))
import Data.List (head, isPrefixOf)


data CliError = UnrecognisedLong String
              | UnrecognisedShort Char
              | UnexpectedPositional String
              | MissingParam String
              | MalformedFlag String
              | UserError String
              | Impossible
              deriving (Show, Eq)

data Or l r = OrLeft l
            | OrRight r
            | OrBoth l r

data Arg = Positional String
         | ShortFlag Char
         | LongFlag String
         | Hyphens Int

instance Show Arg where
  show (Positional arg) = arg
  show (Hyphens count) = replicate count '-'
  show (ShortFlag c) = ['-', c]
  show (LongFlag f) = "--" <> f

data Consume m f args where
  ConsumeArg :: Monad m => Consume m f args -> Consume m (String -> f) args
  FinalizeArg :: Monad m => Consume m (args -> ExceptT CliError m args) args

data FlagSpec m args where
  FlagSpec :: Or Char String -> Consume m f args -> f -> FlagSpec m args

class CliArgs args where
  defaults :: args
  finalize :: Monad m => args -> ExceptT CliError m args
  positional :: Monad m => args -> String -> ExceptT CliError m args
  hyphens :: Monad m => args -> Int -> ExceptT CliError m args
  flags :: Monad m => [FlagSpec m args]
  

parseArgs :: (CliArgs args, Monad m) => [String] -> m (Either CliError args)
parseArgs args = runExceptT $ argParser defaults args

argParser :: (CliArgs args, Monad m) => args -> [String] -> ExceptT CliError m args
argParser acc [] = finalize acc
argParser acc (s : ss) = do
  arg <- classifyArg s
  (acc', ss') <- case arg of
    Positional p -> positional acc p <&> flip (,) ss
    Hyphens len -> hyphens acc len <&> flip (,) ss
    flag -> do
      spec <- findFlag flag flags
      parseFlag flag spec acc ss
  argParser acc' ss'

classifyArg :: Monad m => String -> ExceptT CliError m Arg
classifyArg ['-'] = return $ Hyphens 1
classifyArg ('-' : '-' : flag)
  | all (== '-') flag = return . Hyphens $ length flag + 2
  | otherwise = return $ LongFlag flag
classifyArg ('-' : flag : []) = return $ ShortFlag flag
classifyArg flag@('-' : _) = throwError $ MalformedFlag flag
classifyArg arg = return $ Positional arg

findFlag :: Monad m => Arg -> [FlagSpec m args] -> ExceptT CliError m (FlagSpec m args)
findFlag (Positional _) _ = throwError Impossible
findFlag (Hyphens _) _ = throwError Impossible
findFlag (ShortFlag f) [] = throwError $ UnrecognisedShort f
findFlag (LongFlag f) [] = throwError $ UnrecognisedLong f
findFlag flag@(ShortFlag f) (spec@(FlagSpec (OrLeft m) _ _) : specs)
  | f == m = return spec
  | otherwise = findFlag flag specs
findFlag flag@(ShortFlag f) (spec@(FlagSpec (OrBoth m _) _ _) : specs)
  | f == m = return spec
  | otherwise = findFlag flag specs
findFlag flag@(LongFlag f) (spec@(FlagSpec (OrRight m) _ _) : specs)
  | f == m = return spec
  | otherwise = findFlag flag specs
findFlag flag@(LongFlag f) (spec@(FlagSpec (OrBoth _ m) _ _) : specs)
  | f == m = return spec
  | otherwise = findFlag flag specs

parseFlag :: Monad m => Arg -> FlagSpec m args ->
             args -> [String] -> ExceptT CliError m (args, [String])
parseFlag _ (FlagSpec _ FinalizeArg parse) args ss = parse args <&> flip (,) ss
parseFlag arg (FlagSpec _ (ConsumeArg ty) parse) args [] = throwError . MissingParam $ show arg
parseFlag arg (FlagSpec f (ConsumeArg ty) parse) args (s : ss) =
  parseFlag arg (FlagSpec f ty (parse s)) args ss
