-----------------------------------------------------------------------------------------
{-| Module      : Layout.ScanLib
    Copyright   : (c) 2007 Martijn Schrage
    License     : All Rights Reserved

    Maintainer  : martijn@cs.uu.nl
    Stability   : experimental
    Portability : 

This module is imported by the Alex scanner. Because of the module exports, the scanner
only needs to import this module (and DocTypes_Generated for the token data type).

Some scanner functionality could not be factorized and can be found in AlexTemplate-ghc

-}
-----------------------------------------------------------------------------------------

module Layout.ScanLib ( module Layout.ScanLib
                      , module Data.Maybe
                      , module Common.DebugLevels
                      , module Layout.LayLayerTypes
                      , module Layout.LayLayerUtils
                      )  where

import Common.CommonTypes
import Common.DebugLevels
import Layout.LayLayerTypes
import Layout.LayLayerUtils hiding (empty)
import qualified Data.Map as Map hiding (mapMaybe, (!))
import Data.Maybe
import Data.Word (Word8)

{-
-- Original alex 3.1.3 version
alexGetByte :: AlexInput -> Maybe (Byte,AlexInput)
alexGetByte (c,(b:bs),s) = Just (b,(c,bs,s))
alexGetByte (c,[],[])    = Nothing
alexGetByte (_,[],(c:s)) = case utf8Encode c of
                             (b:bs) -> Just (b, (c, bs, s))
                             [] -> Nothing
-}


{-
alexGetChar (_, [])   = Nothing
alexGetChar (_, Char _ _ _ _ c : cs) = Just (c, (c,cs))
alexGetChar (_, Structural _ _ _ _ _ _ : cs) = Just ('\255', ('\255', cs))
-}

alexInputPrevChar (c,_) = c

mkToken = mkTokenEx id

-- the first strf is for manipulating the string that is stored in the token
mkTokenEx :: (String->String) -> (String -> userToken) -> ScannerState -> [ScanChar doc enr node clip userToken] -> 
           (ScannedToken doc enr node clip userToken, ScannerState)
mkTokenEx strf tokf (startCode,tokenPos) scs =
  let str = strf $ stringFromScanChars scs
      idp = idPFromScanChars scs
      loc = locFromScanChars scs
      userToken = tokf str

  in  ( ScannedToken (getFocusStartEnd scs) $ UserTk tokenPos userToken str loc idp
      , (startCode,tokenPos + 1)
      )

collectWhitespace :: ScannerState -> [ScanChar doc enr node clip userToken] ->
                     (ScannedToken doc enr node clip userToken, ScannerState)
collectWhitespace tokenPos scs =
  let whitespaceChars = stringFromScanChars scs
      scannedWhitespace = ( length (filter (=='\n') whitespaceChars)
                          , length (takeWhile (==' ') (reverse whitespaceChars))
                          )
  in  ( ScannedWhitespace (getFocusStartEnd scs) scannedWhitespace
      , tokenPos
      )
