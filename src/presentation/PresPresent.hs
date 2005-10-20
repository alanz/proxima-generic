module PresPresent where

import CommonTypes
import PresLayerTypes
import PresLayerUtils

import Presenter


presentIO :: PresentationSheet doc node -> LayerStatePres -> EnrichedDocLevel ->
             PresentationLevel doc node -> EditEnrichedDoc' ->
             IO (EditPresentation' doc node, LayerStatePres, EnrichedDocLevel)
presentIO presentationSheet state high low@(PresentationLevel pres layout) editHigh =
  let (editLow, state', high') = present presentationSheet state high low editHigh
  in do { -- debugLnIO Prs ("editDoc':"++show editHigh)
        --; debugLnIO Prs ("editPres':"++show editLow)
        ; return $ (editLow, state', high')
        }


-- inss and dels are passed in a bizarre way now because lower local state may not be updated
-- at the translation side
-- inserted and deleted are taken from setDoc' and put in PresentationLevelState
-- on document edit, old inserted and deleted from level are reused

present :: PresentationSheet doc node -> LayerStatePres -> EnrichedDocLevel ->
           PresentationLevel doc node -> EditEnrichedDoc' ->
           (EditPresentation' doc node, LayerStatePres, EnrichedDocLevel)
present _ state enrLvl (PresentationLevel pres layout) (SkipEnr' 0) = {-debug Prs ("Present:"++show pres++"\n focus "++show focus)-} 
  (SetPres' (PresentationLevel pres layout), state, enrLvl)  -- we should re present here because of local state
present _ state enrlvl pres                            (SkipEnr' i) = (SkipPres' (i-1), state, enrlvl)
present presentationSheet state (EnrichedDocLevel enr _) (PresentationLevel pres (layoutMap,idC  , _,_  )) (SetEnr' enrlvl)  =
    
  let --focusXY             = saveFocus focus pres
      (pres', layoutMap', idC')      = presentEnr presentationSheet state enrlvl layoutMap idC
      --focus'              = restoreFocus focusXY pres'

      --  (pres'', focus'') = (pres',focus')--normalizePresentation pres focus
  in  (SetPres' (PresentationLevel pres' (layoutMap', idC' , [] , emptyFM {-, inss, dels -} {- [(IDP 2, StringP (IDP (-1)) "deleted")
                                                                                     ,(IDP (-1), StringP (IDP (-2)) "both")
                                                                                     ] -} )), state, enrlvl)
