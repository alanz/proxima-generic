module Arranger where

import CommonTypes
import ArrLayerTypes
import ArrLayerUtils

import ArrangerAG
--import FontLibGTK
import FontLib
import Data.IORef

import qualified Data.Map as Map
import Data.Map (Map)

arrangePresentation :: Show node => LocalStateArr -> FontMetricsRef -> FocusPres -> Arrangement node ->
                       DiffTree -> Presentation doc node clip -> IO (Arrangement node, LocalStateArr)
arrangePresentation state fontMetricsRef focus oldArrangement dt pres =

 do { viewedArea <- readIORef $ getViewedAreaRef state
    ; let lastViewedArea = getLastViewedArea state
          state' = state { getLastViewedArea = viewedArea }
          pres' = prunePres viewedArea lastViewedArea (0,0) oldArrangement dt pres
    ; putStrLn $ "Viewed area: "++show viewedArea ++ " last viewed area: "++show lastViewedArea
    ; debugLnIO Err ("Diff tree"++show dt)
 --   ; debugLnIO Err ("Pruned presentation"++show pres')
    ; (attrTree, maxFDepth, unfoldedTree) <- fixed fontMetricsRef focus pres' viewedArea oldArrangement
 -- ; debugLnIO Arr ("  maxFormatterDepth = "++ show maxFDepth)   
          
    ; if maxFDepth == 0 then
        return (attrTree, state')
      else if maxFDepth == 1 
      then 
       do { (arrangement, maxFDepth, unfoldedTree) <- fixed fontMetricsRef focus unfoldedTree viewedArea oldArrangement
          ; return (arrangement, state')
          }
      else 
        debug Err "no nested formatters allowed yet" (return (attrTree, state'))
 
   
    }

-- non-pure font queries mess up this computation. Using a fixIO does not work because we are in the IO monad, and
-- unsafePerformDraw is not available     -- obsolete comment
-- Monad is IO again so fixIO can be used
fixed :: Show node => FontMetricsRef -> FocusPres -> Presentation doc node clip -> Rectangle -> 
         Arrangement node -> IO (Arrangement node, Integer, Presentation doc node clip)
fixed fontMetricsRef focus (pres :: Presentation doc node clip) viewedArea oldArrangement = f --fixit
 where f :: IO (Arrangement node, Integer, Presentation doc node clip) -- doc and node are scoped type variables
       f = 
         do { let (defBackColor, defFillColor, defLineColor, defTextColor) = (transparent, white, black, black)
            ; let defFont = defaultFont 
            
            ; debugLnIO Arr ("Start collecting fonts")
            ; let (allFonts, _, _, _ ) =
                    sem_Root (Root pres) [defFont]
                                               defBackColor defFillColor
                                               focus
                                               defFont 
                                               Map.empty --(error "font computation depends on font metrics")
                                               defLineColor
                                               Nothing  -- mouseDown : Maybe (UpdateDoc doc clip)
                                               oldArrangement
                                               []       -- popupMenu : [String, (UpdateDoc doc clip)] 
                                               defTextColor
                                               viewedArea
               
            ; let usedFonts = nub allFonts
            ; seq (length allFonts) $ return ()
           -- ; debugLnIO Arr ("Done collecting fonts")
             
           -- ; debugLnIO Arr ("The fonts are:"++show usedFonts)
            ; queriedMetrics <- readIORef fontMetricsRef
            
            ; let queriedFonts = Map.keys queriedMetrics
            ; let newFonts =  deleteFirstsBy (==) usedFonts queriedFonts -- usedFonts was nubbed
{-
            ; debugLnIO Arr $ "used: "           ++ show usedFonts
            ; debugLnIO Arr $ "already queried: "++ show queriedFonts
            ; debugLnIO Arr $ "new:             "++ show newFonts
-}
            -- filter the ones that are already present

            ; newMetrics <- mkFontMetrics newFonts
            ; let updatedMetrics = newMetrics `Map.union` queriedMetrics
            ; writeIORef fontMetricsRef updatedMetrics
            
            ; let (_, arrangement,  maxFDepth, unfoldedTree) =
                    sem_Root (Root pres) [defFont]
                                          defBackColor defFillColor
                                          focus
                                          defFont
                                          updatedMetrics
                                          defLineColor
                                          Nothing
                                          oldArrangement
                                          []
                                          defTextColor
                                          viewedArea 
                                          
            ; return (arrangement, maxFDepth, unfoldedTree)
            }
            
     