module Evaluation.EvalPresent where

import Common.CommonTypes
import Evaluation.EvalLayerTypes
import Evaluation.EvalLayerUtils

import Evaluation.DocumentEdit

presentIO :: (Doc doc, Clip clip, Editable doc doc node clip token, EvaluationSheet doc enr clip) =>
             LayerStateEval -> DocumentLevel doc clip -> EnrichedDocLevel enr doc ->
             EditDocument' doc clip ->
             IO (EditEnrichedDoc' enr doc, LayerStateEval, DocumentLevel doc clip)
presentIO state high low editHigh =
  do { (editLow, state', high') <- eval state high low editHigh
     
     --; debugLnIO Prs ("editDoc':"++show editHigh)
     --; debugLnIO Prs ("editEnr':"++show editLow)
     ; return $ (editLow, state', high')
     }

{-
eval :: (Doc doc, Clip clip, Editable doc doc node clip token, EvaluationSheet doc enr clip) =>
             LayerStateEval -> DocumentLevel doc clip -> EnrichedDocLevel enr ->
             EditDocument' doc clip doc ->
             IO (EditEnrichedDoc' enr, LayerStateEval, DocumentLevel doc clip)
-}
eval state docLvl@(DocumentLevel doc focusD clipD) enrLvl docEdit =
  case docEdit of 
    SkipDoc' 0 -> return (SetEnr' enrLvl, state, docLvl)  -- we should re-evaluate here because of local state
    SkipDoc' i -> return (SkipEnr' (i-1), state, docLvl)
    SetDoc' docLvl  -> evaluationSheet state docLvl enrLvl docEdit docLvl
    EvaluateDoc' -> evaluationSheet state docLvl enrLvl docEdit docLvl
    _ -> debug Eva ("DocNavigate"++show focusD) $
          do { let (doclvl', state') = editDoc state docLvl docEdit
             ; evaluationSheet state' docLvl enrLvl docEdit doclvl'
             }

-- TODO: make sure that document is parsed before doing these:
editDoc :: (Doc doc, Clip clip, Editable doc doc node clip token) =>
           LayerStateEval -> DocumentLevel doc clip -> EditDocument' doc clip ->
           (DocumentLevel doc clip, LayerStateEval)
editDoc state doclvl                        (UpdateDoc' upd) = (upd doclvl, state)
editDoc state (DocumentLevel doc pth clipD) NavUpDoc'        = ((DocumentLevel doc (navigateUpD pth doc) clipD), state)
editDoc state (DocumentLevel doc pth clipD) NavDownDoc'      = ((DocumentLevel doc (navigateDownD pth doc) clipD), state)
editDoc state (DocumentLevel doc pth clipD) NavLeftDoc'      = ((DocumentLevel doc (navigateLeftD pth doc) clipD), state)
editDoc state (DocumentLevel doc pth clipD) NavRightDoc'     = ((DocumentLevel doc (navigateRightD pth doc) clipD), state)
editDoc state doclvl                        CutDoc'          = (editCutD doclvl, state)
editDoc state doclvl                        CopyDoc'         = (editCopyD doclvl, state)
editDoc state doclvl                        PasteDoc'        = (editPasteD doclvl, state)
editDoc state doclvl                        DeleteDoc'       = (editDeleteD doclvl, state)
editDoc state doclvl                        op               = debug Err ("EvalPresent:unhandled doc edit: "++show op) (doclvl, state)