module Rendering.RenInterpret where

import Common.CommonTypes
import Rendering.RenLayerTypes
import Rendering.RenLayerUtils
import Proxima.Wrap
import Evaluation.DocTypes 
import Layout.LayTypes
import Evaluation.EnrTypes
import Data.Char
import Control.Exception
-- import IOExts

interpretIO state low high = castRemainingEditOps $ \editLow -> 
 do { (editHigh, state', low') <- gInterpretIO state low high editLow
    ; return (editHigh, state', low')
    }



-- descaling seems a bit messy, maybe we should do it before processing the edit command

-- updating rendering does not seem to make sense
-- apply key remapper first

-- edit ops are recognized here because they need the focus. When focus is handled differently, the
-- edit ops might be recognized elsewhere in the future
-- focus is passed all the time, which is a hint that the current focus model is no good
-- also focus behaviour (e.g. what to do when navigating with a nonempty focus) is split over layers

--gInterpret stands for gesture interpret
gInterpretIO :: (Show doc, Show enr, Show token, Show node) =>
             LocalStateRen -> RenderingLevel doc enr node clip token ->
             ArrangementLevel doc enr node clip token -> EditRendering doc enr node clip token ->
             IO ([EditArrangement doc enr node clip token], LocalStateRen, RenderingLevel doc enr node clip token)
gInterpretIO state renLvl@(RenderingLevel scale c r fr sz debugging ur lmd)
                arrLvl@(ArrangementLevel arr focus _) editRen = debug Ren ("Rendering edit:"++show editRen) $
  case editRen of
    KeySpecialRen UpKey ms@(Modifiers False False False) ->
     do { editArr <- tryFocus upFocus Up (getViewedAreaRefRen state) focus (if debugging then debugArrangement arr else arr) $ 
                       castRen $ KeySpecialRen UpKey ms
        ; return (editArr, state, renLvl)
        }
    KeySpecialRen DownKey ms@(Modifiers False False False) ->
     do { editArr <- tryFocus downFocus Down (getViewedAreaRefRen state) focus (if debugging then debugArrangement arr else arr) $ 
                       castRen $ KeySpecialRen DownKey ms
        ; return (editArr, state, renLvl)
        }
    KeySpecialRen UpKey ms@(Modifiers True False False)   -> -- shift down
     do { editArr <- tryFocus enlargeFocusUp Up (getViewedAreaRefRen state) focus (if debugging then debugArrangement arr else arr) $ 
                       castRen $ KeySpecialRen UpKey ms
        ; return (editArr, state, renLvl)
        }
    KeySpecialRen DownKey ms@(Modifiers True False False) -> -- shift down
     do { editArr <- tryFocus enlargeFocusDown Down (getViewedAreaRefRen state) focus (if debugging then debugArrangement arr else arr) $ 
                       castRen $ KeySpecialRen DownKey ms
        ; return (editArr, state, renLvl)
        }
    _ -> return $ gInterpret state renLvl arrLvl editRen

 
gInterpret :: (Show doc, Show enr, Show token, Show node) =>
             LocalStateRen -> RenderingLevel doc enr node clip token ->
             ArrangementLevel doc enr node clip token -> EditRendering doc enr node clip token ->
             ([EditArrangement doc enr node clip token], LocalStateRen, RenderingLevel doc enr node clip token)
gInterpret state renLvl@(RenderingLevel scale c r fr sz debugging ur lmd)
                arrLvl@(ArrangementLevel arr focus _) editRen = debug Ren ("Rendering edit:"++show editRen) $
  case editRen of
    InitRen             -> ([InitArr],       state, renLvl) 
    CloseRen            -> ([CloseArr],      state, renLvl)
    SkipRen i           -> ([SkipArr (i+1)], state, renLvl)
-- TODO: make selectors scaleR and debuggingR for RenderingLevel
    KeySpecialRen (CharKey 'c') (Modifiers False True False) -> ([CopyArr],       state, renLvl) -- Ctrl-c
    KeySpecialRen (CharKey 'g') (Modifiers False True False) -> ([castLay $ FindLay Nothing],       state, renLvl) -- Ctrl-c
    KeySpecialRen (CharKey 's') (Modifiers False True False) -> ([castEnr $ SaveFileEnr defaultDocumentFilename],       state, renLvl) -- Ctrl-c
    KeySpecialRen (CharKey 'v') (Modifiers False True False) -> ([PasteArr],      state, renLvl) -- Ctrl-v
    KeySpecialRen (CharKey 'x') (Modifiers False True False) -> ([CutArr],        state, renLvl) -- Ctrl-x
    KeySpecialRen (CharKey 'c') (Modifiers True True False) -> ([castDoc' $ CopyDoc'],    state, renLvl) -- Ctrl-C
    KeySpecialRen (CharKey 'v') (Modifiers True True False) -> ([castDoc' $ PasteDoc'],   state, renLvl) -- Ctrl-V
    KeySpecialRen (CharKey 'x') (Modifiers True True False) -> ([castDoc' $ CutDoc'],     state, renLvl) -- Ctrl-X
    KeySpecialRen (CharKey 'z') (Modifiers False True False) -> ([castDoc' $ UndoDoc'],     state, renLvl) -- Ctrl-z
    KeySpecialRen (CharKey 'y') (Modifiers False True False) -> ([castDoc' $ RedoDoc'],     state, renLvl) -- Ctrl-y
    KeySpecialRen UpKey   (Modifiers False False True) -> ([SkipArr 0], state, RenderingLevel (scale*2) c r fr sz debugging ur lmd)
    KeySpecialRen DownKey (Modifiers False False True) -> ([SkipArr 0], state, RenderingLevel (scale/2) c r fr sz debugging ur lmd)
    KeySpecialRen F9Key ms                             -> ([SkipArr 0], state, RenderingLevel scale c r fr sz (not debugging) ur lmd)

    KeySpecialRen UpKey (Modifiers False True False)    -> ([castDoc' $ NavUpDoc'], state, renLvl) -- Ctrl
    KeySpecialRen DownKey (Modifiers False True False)  -> ([castDoc' $ NavDownDoc'], state, renLvl) -- Ctrl
    KeySpecialRen LeftKey (Modifiers False True False)  -> ([castDoc' $ NavLeftDoc'], state, renLvl) -- Ctrl
    KeySpecialRen RightKey (Modifiers False True False) -> ([castDoc' $ NavRightDoc'], state, renLvl) -- Ctrl
    KeySpecialRen LeftKey (Modifiers True False False)  -> ([EnlargeLeftArr], state, renLvl) -- Shift
    KeySpecialRen RightKey (Modifiers True False False) -> ([EnlargeRightArr], state, renLvl) -- Shift
    
    KeySpecialRen EnterKey ms     -> ([SplitArr], state, renLvl)
    KeySpecialRen BackspaceKey ms -> ([LeftDeleteArr], state, renLvl)
    KeySpecialRen DeleteKey ms    -> ([RightDeleteArr], state, renLvl)
    KeySpecialRen LeftKey ms      -> ([LeftArr], state, renLvl)
    KeySpecialRen RightKey ms     -> ([RightArr], state, renLvl)
    KeySpecialRen F1Key ms        -> ([castLay ParseLay], state, renLvl)
    KeySpecialRen F2Key ms        -> ([castDoc' $ EvaluateDoc']
                                     , state, renLvl)
    KeySpecialRen F5Key ms        -> ([RedrawArr], state, renLvl)



    KeyCharRen c          -> ([KeyCharArr c], state, renLvl)
    KeySpecialRen c ms    -> ([KeySpecialArr c ms], state, renLvl)
    MouseDownRen x y ms i -> ([MouseDownArr (descaleInt scale x) (descaleInt scale y) ms i], state, RenderingLevel scale c r fr sz debugging ur True)
    MouseDragRen x y ms   -> ([MouseDragArr (descaleInt scale x) (descaleInt scale y) ms], state, renLvl)
    MouseUpRen x y ms     -> ([MouseUpArr (descaleInt scale x) (descaleInt scale y) ms], state, RenderingLevel scale c r fr sz debugging ur False)
    
    DragStartRen x y      -> ([DragStartArr (descaleInt scale x) (descaleInt scale y)], state, RenderingLevel scale c r fr sz debugging ur True)
    DropRen x y           -> ([DropArr (descaleInt scale x) (descaleInt scale y)], state, RenderingLevel scale c r fr sz debugging ur False)

    OpenFileRen filePath  -> ([OpenFileArr filePath],  state, renLvl) 
    SaveFileRen filePath  -> ([SaveFileArr filePath],  state, renLvl) 
    GuaranteeFocusInViewRen -> ([GuaranteeFocusInViewArr], state, renLvl)
    WrapRen wrapped       -> ([unwrap wrapped],        state, renLvl)
    _                     -> ([SkipArr 0],             state, renLvl)
