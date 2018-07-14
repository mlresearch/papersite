module Main where

import Page
import Control.Monad        (forM_, liftM)
import Data.AssocList       (addEntry)
import Data.Char            (toUpper, isDigit)
import Data.Function        (on)
import Data.Functor         ((<$>))
import Data.List            (sort, lookup)
import Data.Maybe           (fromJust)
import System.Directory     (getDirectoryContents)
import System.FilePath      (joinPath, takeExtension)
import System.Environment   (getArgs)
import Text.BibTeX.Entry    (T(Cons), entryType, identifier, fields)
import Text.BibTeX.Parse    (file)
import Text.Parsec          (parse)

import qualified Text.BibTeX.Format as Format (entry)

-- Usage example: update db/v1 20 35 notable
-- Adds section = {notable} to all .bib entries in db/v1 with first page
-- in the given range
main = do
  args <- getArgs 
  case args of
    -- Correct number of arguments
    [vol, start, end, section] -> do
      putStrLn $ 
        "Adding 'section={" ++ section ++ "}' to " ++ vol ++
          " for pages " ++ start ++ "--" ++ end
      let startPos = orderValue start
      let endPos   = orderValue end
      
      -- Get list of paths to .bib files for given volume
      files <- addInitPath vol <$> getDirectoryContents vol
      let bibfiles = filter ((== ".bib") . takeExtension) files

      -- Parse and filter entries into [(path, entry)]
      parsed <- sequence $ map parseEntry $ bibfiles
      let selected = filter (inRange startPos endPos . snd) parsed

      -- For each entry add the section field and overwrite
      forM_ selected $ \(path,entry) -> do
        let newEntry = updateField "section" section entry
        writeFile path $ Format.entry newEntry  
        putStrLn $ "Updated " ++ path

    -- Bad args: display usage information
    _ -> putStrLn $ "Usage: update VOLPATH START END SECTION"

-- Test whether entry has first page in correct range
inRange start end entry = pagePos >= start && pagePos < end
  where pagePos = orderValue . fromJust . firstPage $ entry

-- Parse a single entry given its path
parseEntry path = either (error "Bad parse") (\ts -> (path, head ts)) <$> 
  liftM (parse file path) (readFile path) 

-- Adds an inital path to elements of a list
addInitPath path = map (joinPath . (\x -> [path,x]))

--------------------------------------------------------------------------------
-- Managing entry ordering

-- Look up the given key in a BibTeX entry
get :: String -> T -> Maybe String
get key = lookup key . fields

-- Change the value in an entry's fields
updateField :: String -> String -> T -> T
updateField key value t =
  Cons {
    entryType   = entryType t,
    identifier  = identifier t,
    fields      = addEntry key value $ fields t
  }

-- Is the character a valid roman or arabic digit?
isPageDigit :: Char -> Bool
isPageDigit c = isDigit c || isRoman c

--------------------------------------------------------------------------------
-- Handle roman numerals in page numbers
romanChars = "IVXLCDM"

isRoman :: Char -> Bool
isRoman = flip elem romanChars . toUpper

isRomanStr :: String -> Bool
isRomanStr = isRoman . head

romanToInt :: String -> Int
romanToInt = fst . foldr (\p (t,s) -> 
    if p >= s then (t+p,p) else (t-p,p)) (0,0) . map 
      (fromJust . flip lookup (zip "IVXLCDM" [1,5,10,50,100,500,1000]))
