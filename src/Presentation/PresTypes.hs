{-# LANGUAGE GADTs              #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE EmptyDataDecls     #-}
module Presentation.PresTypes where

import Common.CommonTypes
import Evaluation.DocTypes (DocumentLevel)
import {-# SOURCE #-} Proxima.Wrap
import Common.CommonUtils

import qualified Data.Map as Map
import Data.Map (Map)
import Data.Generics

import UU.Parsing

data IDP = NoIDP | IDP Int deriving (Show, Read, Eq, Ord, Data, Typeable)

data PresentationLevel doc enr node clip token = PresentationLevel (Presentation doc enr node clip token) (PresentationLS doc enr node clip token) deriving Show

type PresentationLS doc enr node clip token = (WhitespaceMap, IDPCounter)

type Whitespace = (Int, Int) -- (line breaks, spaces)

type FocusStartEnd = (Maybe Int, Maybe Int)

type WhitespaceFocus = ((Int,Int), FocusStartEnd)

data TokenLayout = TokenLayout { whitespace :: Whitespace
                               , whitespaceFocus :: FocusStartEnd -- trailing whitespace & focus
                               , tokenFocus :: FocusStartEnd      -- focus in token 
                               } deriving Show

type WhitespaceMap = Map IDP TokenLayout   -- Whitespace information for each element in Presentation

type IDPCounter = Int                   -- Counter for generating new unique IDPs

--instance (Show a, Show b) => Show (FiniteMap a b) where
-- show fm = "{FiniteMap}" -- ++show (fmToList fm)


initLayout :: WhitespaceMap
initLayout = Map.fromList []

type ParseErrorMessage = (Maybe Int, String)

getErrorMessages (ParsingParseErr _ msgs _ _ _) = msgs
getErrorMessages _                          = [(Nothing, "Structural parse error")]
-- structural parse errors should not occur and therefore do not need to be
-- accessible in the presentation AG (other than this string).

data ParseError doc enr node clip token = ParsingParseErr IDP [ParseErrorMessage] [Token doc enr node clip token] Lexer (ClipParser doc enr node clip token)
                                    | StructuralParseErr (Presentation doc enr node clip token) deriving Typeable
-- only for Parse errors in the parsing presentations, we keep track of the parse error.
-- structural parse errors cannot be represented with a list of tokens.

instance (Typeable doc, Typeable enr, Typeable node, Typeable clip, Typeable token) => 
         Data (ParseError doc enr node clip token) where

instance Show (ParseError doc enr node clip token) where
  show (ParsingParseErr _ _ _ _ _) = "ParsingParseErr"
  show (StructuralParseErr _) = "StructuralParseErr"

data EditPresentation'_ wrapped doc enr node clip token =
    SetPres' (PresentationLevel doc enr node clip token)
  | SkipPres' Int
  | WrapPres' wrapped deriving Show

data EditPresentation_ wrapped doc enr node clip token =
    SkipPres Int
  | SetFocusPres FocusPres
  | SetPres (PresentationLevel doc enr node clip token)
  | InitPres
  | ClosePres
--  | MouseDownPres PathPres Modifiers Int
  | NormalizePres
  | TestPres
  | Test2Pres
  | OpenFilePres String
  | SaveFilePres String
   
  | WrapPres wrapped deriving Show

type Position = Int

type ListParser doc enr node clip token a = Parser (Token doc enr node clip token) a 

type ClipParser doc enr node clip token = [Token doc enr node clip token] -> clip

data Token doc enr node clip token = 
               UserTk       Position token String (Maybe node) IDP
             | StructuralTk Position (Maybe node) (Presentation doc enr node clip token) [Token doc enr node clip token] IDP
             | StyleTk      Position ScannedStyleTag
             | ParsingTk    (Maybe (ClipParser doc enr node clip token)) (Maybe node)  [Token doc enr node clip token] IDP -- deriving (Show)
             | GraphTk               Dirty [(Int, Int)] (Maybe node) IDP
             | VertexTk              Int (Int, Int) (Maybe node) IDP
             | ErrorTk      Position String IDP -- for storing scanner errors
-- the IDP field is used during the scanning and parsing phase.

-- The Position field in UserTk StructuralTk and ErrorTk contains its position in the list of scanned tokens
-- The other tokens are not produced by the scanner, and therefore do not need this field.
-- The position is only used for children of ParsingTk. StructuralTk children of a StructuralTk all have
-- position 0

data ScannedStyleTag = ScannedStyleTag ScannedStyle StartOrEnd deriving (Show, Eq, Ord)

data ScannedStyle = ScannedBold | ScannedItalic | ScannedFontSize Int | ScannedColor Color deriving (Show, Read)

-- special version of Style in which Color x == Color y = True even if x /= y, necessary for UU.Parsing, so we can write one parser for
-- all colors.

instance Eq ScannedStyle where 
  ScannedBold       == ScannedBold       = True
  ScannedItalic     == ScannedItalic     = True
  ScannedFontSize s1 == ScannedFontSize s2 = True
  ScannedColor c1 == ScannedColor c2 = True
  _                 == _                 = False

instance Ord ScannedStyle where
  ScannedBold      <= ScannedBold      = True
  ScannedItalic    <= ScannedItalic    = True
  ScannedItalic    <= ScannedBold      = True
  ScannedFontSize _ <= ScannedFontSize _ = True
  ScannedFontSize _ <= ScannedItalic    = True
  ScannedFontSize _ <= ScannedBold      = True
  ScannedColor _ <= ScannedColor _ = True
  ScannedColor _ <= ScannedFontSize _ = True
  ScannedColor _ <= ScannedItalic    = True
  ScannedColor _ <= ScannedBold      = True
  _                <= _                = False


isStyleTk (StyleTk _ _) = True
isStyleTk _             = False

instance (Show node, Show token) => Show (Token doc enr node clip token) where
  show (UserTk nr u s _ id)         = "<"++show nr ++":"++"UserTk "++show u++":"++show s++":"++show id++">"
  show (StructuralTk nr Nothing _ tks id) = "<"++show nr ++":"++"structural:Nothing:"++show id++">" 
  show (StructuralTk nr (Just node) _ tks id) = 
    let showNode = show node -- not the nicest way of showing the constructor. Maybe include this in the node class
        nodeStr = if "Node_" `isPrefixOf` showNode
                  then drop (length "Node_") showNode
                  else showNode
    in  "<"++show nr ++":StructuralTk:"++nodeStr++":"++show id++">" 
  show (StyleTk _ tag)       = "<StyleTk:"++show tag++">" 
  show (ParsingTk _ _ tks _)       = "<ParsingTk>" 
  show (GraphTk _ edges _ _)     = "<GraphTk:"++show edges++">"
  show (VertexTk id pos _ _)     = "<VertexTk: "++show id++">"
  show (ErrorTk nr str id)             = "<"++show nr ++":"++"ErrorTk: "++show str++":"++show id++">"

instance (Eq node, Eq token) => Eq (Token doc enr node clip token) where
  UserTk _ u1 _ _ _     == UserTk _ u2 _ _ _     = u1 == u2
  StructuralTk _ Nothing _ _ _    == StructuralTk _ _ _ _ _ = True       -- StructuralTks with no node always match
  StructuralTk _ _ _ _ _          == StructuralTk _ Nothing _ _ _ = True -- StructuralTks with no node always match
  StructuralTk _ (Just nd1) _ _ _ == StructuralTk _(Just nd2) _ _ _ = nd1 == nd2 -- Eq on Node is based on rankNode
  StyleTk _ tag1  == StyleTk _ tag2 = tag1 == tag2   
  ParsingTk _ _ _ _   == ParsingTk _ _ _ _ = True   
  GraphTk _ _ _ _  == GraphTk _ _ _ _  = True
  VertexTk _ _ _ _ == VertexTk _ _ _ _ = True -- if we want to recognize specific vertices, maybe some
                                              -- identifier will be added, which will be involved in eq. check
  ErrorTk _ _ _ == ErrorTk _ _ _             = True
  _              == _                  = False

instance (Ord node, Ord token) => Ord (Token doc enr node clip token) where
  UserTk _ u1 _ _ _      <= UserTk _ u2 _ _ _    = u1 <= u2
  StructuralTk _ Nothing _ _ _    <= StructuralTk _ _ _ _ _ = True     
  StructuralTk _ _ _ _ _          <= StructuralTk _ Nothing _ _ _ = True
  StructuralTk _ (Just nd1) _ _ _ <= StructuralTk _ (Just nd2) _ _ _ = nd1 <= nd2 -- Ord on Node is based on rankNode
  StructuralTk _ _ _ _ _ <= UserTk _ _ _ _ _  = True
  StyleTk _ tag1 <= StyleTk _ tag2      = tag1 <= tag2
  StyleTk _ _ <= StructuralTk _ _ _ _ _ = True
  StyleTk _ _ <= UserTk _ _ _ _ _       = True
  ParsingTk _ _ _ _ <= ParsingTk _ _ _ _      = True
  ParsingTk _ _ _ _ <= StyleTk _ _            = True
  ParsingTk _ _ _ _ <= StructuralTk _ _ _ _ _ = True
  ParsingTk _ _ _ _ <= UserTk _ _ _ _ _       = True
  GraphTk _ _ _ _ <= GraphTk _ _ _ _      = True
  GraphTk _ _ _ _ <= ParsingTk _ _ _ _      = True
  GraphTk _ _ _ _ <= StyleTk _ _      = True
  GraphTk _ _ _ _ <= StructuralTk _ _ _ _ _ = True
  GraphTk _ _ _ _ <= UserTk _ _ _ _ _       = True
  VertexTk _ _  _ _ <= VertexTk _ _ _ _    = True
  VertexTk _ _ _ _ <= GraphTk _ _ _ _      = True
  VertexTk _ _ _ _ <= ParsingTk _ _ _ _      = True
  VertexTk _ _ _ _ <= StyleTk _ _      = True
  VertexTk _ _ _ _ <= StructuralTk _ _ _ _ _ = True
  VertexTk _ _ _ _ <= UserTk _ _ _ _ _       = True 
  ErrorTk _ _ _        <= ErrorTk _ _ _            = True
  ErrorTk _ _ _        <= VertexTk _ _ _ _     = True
  ErrorTk _ _ _        <= GraphTk _ _ _ _      = True
  ErrorTk _ _ _        <= ParsingTk _ _ _ _      = True
  ErrorTk _ _ _        <= StyleTk _ _      = True
  ErrorTk _ _ _        <= StructuralTk _ _ _ _ _ = True
  ErrorTk _ _ _        <= UserTk _ _ _ _ _       = True
  _                <= _           = False

tokenString :: Token doc enr node clip token -> String                  
tokenString (UserTk _ _ s n id)      = s
tokenString (StructuralTk _ n _ _ id) = "<structural token>"
tokenString (StyleTk _ tag) = "<style token:"++show tag++">"
tokenString (GraphTk d es n id) = "<graph token>"
tokenString (VertexTk i p n id) = "<vertex token>"
tokenString (ErrorTk _ str _)       = str
                             

-- TODO:
-- StructuralTk, we could add a description string to StructuralTk, which is set in the parser and
-- shown here.


tokenNode :: Token doc enr node clip token -> Maybe node                 
tokenNode (StructuralTk _ n _ _ id) = n
tokenNode (GraphTk d es n id) = n
tokenNode (VertexTk i p n id) = n
tokenNode (UserTk _ u s n id)   = n
tokenNode (StyleTk p t)       = error $ "tokenNode called on Style token ("++show p ++ "):" ++ show t
tokenNode (ErrorTk _ str _)       = error $ "tokenNode called on error token: " ++ str

getTokenFontSize (StyleTk _ (ScannedStyleTag (ScannedFontSize s) _)) = s
getTokenFontSize t = debug Err ("getTokenFontSize called on wrong token:" ++ show t) $ 0

getTokenColor (StyleTk _ (ScannedStyleTag (ScannedColor c) _)) = c
getTokenColor t = debug Err ("getTokenColor called on wrong token:" ++ show t) (-1,-1,-1)

getTokenIDP :: Token doc enr node clip token -> IDP
getTokenIDP (UserTk _ u s n id) = id
getTokenIDP (StructuralTk _ n _ _ id)  = id
getTokenIDP (GraphTk d es n id) = id
getTokenIDP (VertexTk i p n id) = id
getTokenIDP (ErrorTk _ str id)  = id
getTokenIDP (StyleTk p t)       = NoIDP

setTokenIDP :: IDP -> Token doc enr node clip token -> Token doc enr node clip token
setTokenIDP idp (UserTk p u s n _)         = UserTk p u s n idp
setTokenIDP idp (StructuralTk p n pr ts _) = StructuralTk p n pr ts idp
setTokenIDP idp (GraphTk d es n id)        = GraphTk d es n idp
setTokenIDP idp (VertexTk i p n _)         = VertexTk i p n idp
setTokenIDP idp (ErrorTk p str _)          = ErrorTk p str idp
setTokenIDP idp (StyleTk p t)              = (StyleTk p t) -- error $ "setTokenIDP called on Style token ("++show p ++ "):" ++ show t

deepShowTks i tok = case tok of
                      (StructuralTk _ _ _ cs _) -> indent i ++ show tok ++ "\n"
                                               ++ indent (i+1)++"[\n"
                                               ++ concatMap (deepShowTks (i+1)) cs 
                                               ++ indent (i+1)++" ]\n"
                      (ParsingTk _ _ cs _) -> indent i ++ show tok ++ "\n"
                                               ++ indent (i+1)++"[\n"
                                               ++ concatMap (deepShowTks (i+1)) cs 
                                               ++ indent (i+1)++" ]\n"
                      _                     -> indent i ++ show tok ++ "\n"
 where indent i = take i (repeat ' ')



data Pres_

type Presentation doc enr node clip token =
       PresentationBase doc enr node clip token Pres_


{-
The level parameter is used to enforce that there are no tokens on the layout layer.
Any presentation containing a TokenP will have type PresentationBase .. Pres_, which
does not match the Layout type (which is PresentationBase doc enr node clip token Lay_).

This also prevents functions on Layout to be applied to values of type Presentation,
while it is still possible to apply a function on the entire type (PresentationBase ... x)
to a values of type Layout, even if the function has a TokenP case. Note that this holds
only for functions on PresentaionBase .. x, so (f:: Presentation -> a) (x :: Layout) does
not work.

Moreover, any function that has a TokenP case will get inferred type Pres_, so if it needs
to work on Layout as well, it should be given an explicit PresentationBase ... x type signature.
-}
data PresentationBase doc enr node clip userToken level where
       EmptyP  :: !IDP ->
                  PresentationBase doc enr node clip userToken level
       StringP :: !IDP -> !String  ->
                  PresentationBase doc enr node clip userToken level
       TokenP  :: !IDP -> !(Token doc enr node clip userToken) ->
                  PresentationBase doc enr node clip userToken Pres_
       ImageP  :: !IDP -> !String -> !ImgStyle ->
                  PresentationBase doc enr node clip userToken level
       PolyP   :: !IDP -> ![Point] -> !LineWidth -> !FillStyle ->
                  PresentationBase doc enr node clip userToken level
       RectangleP :: !IDP -> !Width -> !Height -> !LineWidth -> !FillStyle ->
                     PresentationBase doc enr node clip userToken level
       EllipseP   :: !IDP -> !Width -> !Height -> !LineWidth -> !FillStyle ->
                     PresentationBase doc enr node clip userToken level
       RowP     :: !IDP -> !HRefNr -> ![PresentationBase doc enr node clip userToken level] ->
                   PresentationBase doc enr node clip userToken level
       ColP     :: !IDP -> !VRefNr -> !Formatted -> ![PresentationBase doc enr node clip userToken level] ->
                   PresentationBase doc enr node clip userToken level
       OverlayP :: !IDP -> !Order -> ![ (PresentationBase doc enr node clip userToken level) ] ->
                   PresentationBase doc enr node clip userToken level
       WithP    :: !(AttrRule doc enr node clip userToken) -> !(PresentationBase doc enr node clip userToken level) ->
                   PresentationBase doc enr node clip userToken level
       StructuralP :: !IDP -> !(PresentationBase doc enr node clip userToken level) ->
                   PresentationBase doc enr node clip userToken level
       ParsingP :: !IDP -> !(Maybe (ClipParser doc enr node clip userToken)) -> !Lexer -> !(PresentationBase doc enr node clip userToken level) ->
                   PresentationBase doc enr node clip userToken level
       LocatorP :: node -> !(PresentationBase doc enr node clip userToken level) ->
                   PresentationBase doc enr node clip userToken level
       TagP :: Tags -> !(PresentationBase doc enr node clip userToken level) ->
                   PresentationBase doc enr node clip userToken level

       GraphP   :: !IDP -> !Dirty -> !Width -> !Height -> ![Edge] -> ![PresentationBase doc enr node clip userToken level] ->
                   PresentationBase doc enr node clip userToken level
       VertexP  :: !IDP -> !VertexID -> !XCoord -> !YCoord -> Outline -> !(PresentationBase doc enr node clip userToken level) ->
                   PresentationBase doc enr node clip userToken level
       FormatterP :: !IDP -> ![PresentationBase doc enr node clip userToken level] ->
                     PresentationBase doc enr node clip userToken level
       ArrangedP :: PresentationBase doc enr node clip userToken level
       -- some of these !'s do not make sense (and it's probably time to factorize this thing)


       -- ArrangedP is experimental for incrementality.
       -- arranger gets Presentation in which unchanged subtrees are replaced by
       -- this node. For these subtrees, old arrangement is used


type Point = (Float, Float) -- point coordinates are >= 0 and <= 1
type HRefNr = Int
type VRefNr = Int
type VertexID = Int
type Edge = (VertexID, VertexID)

-- LexInherited can be used if higher in the presentation tree the lexer is already defined.
data Lexer = Lexer LexerState StyledOrNonStyled
           | LexInherited deriving Show

type LexerState = Int -- Alex calls this a start code

data StyledOrNonStyled = Styled | NonStyled deriving Show

instance (Show node, Show token) => Show (PresentationBase doc enr node clip token level) where
  show (EmptyP id)           = "{"++show id++":Empty}"
  show (StringP id str)      = "{"++show id++":"++show str++"}"
  show (TokenP id t)         = "{"++show id++":"++show t++"}"
  show (ImageP id str _)     = "{"++show id++":Image "++str++"}"
  show (PolyP id _ _ _)        = "{"++show id++":Poly}"
  show (RectangleP id _ _ _ _) = "{"++show id++":Rectangle}"
  show (EllipseP id _ _ _ _)   = "{"++show id++":Ellipse}"
  show (RowP id rf press)    = "RowP "++show rf++" ["++concat (intersperse ", " (map show press))++"]"
  show (ColP id rf f press)    = "ColP "++show rf++" "++show f++" ["++concat (intersperse ", " (map show press))++"]"
  show (OverlayP d id press)  = "OverlayP "++show d++" ["++concat (intersperse ", " (map show press))++"]"
  show (WithP ar pres)       = "WithP <fn> "++show pres
  show (StructuralP id pres) = "StructuralP "++show id++" "++show pres
  show (ParsingP id p l pres)    = "ParsingP "++show l++" "++show pres
  show (LocatorP loc pres)   = "LocatorP "++ {- show loc++ -} " "++show pres
  show (TagP tags pres)   = "TagP "++ show tags++ " "++show pres
  show (GraphP id _ _ _ edges press) = "GraphP "++ show edges++" ["++concat (intersperse ", " (map show press))++"]"
  show (VertexP id vid x y ol pres)  = "Vertex (#"++show vid++":"++show x++","++show y++")"++show pres
  show (FormatterP id press) = "FormatterP ["++concat (intersperse ", " (map show press))++"]"
  show (ArrangedP)           = "ArrangedP" -- ++show pres
  show _                     = "<<<presentation without show>>>"


-- shallow presentation, showing only toplevel presentation

shallowShowPres :: (Show node, Show token) => PresentationBase doc enr node clip token level -> String
shallowShowPres (EmptyP id)           = "{"++show id++":Empty}"
shallowShowPres (StringP id str)      = "{"++show id++":StringP "++show str++"}"
shallowShowPres (TokenP id t)         = "{"++show id++":TokenP "++show t++"}"
shallowShowPres (ImageP id str _)       = "{"++show id++":ImageP "++show str++"}"
shallowShowPres (PolyP id _ _ _)        = "{"++show id++":Poly}"
shallowShowPres (RectangleP id _ _ _ _) = "{"++show id++":Rectangle}"
shallowShowPres (EllipseP id _ _ _ _)   = "{"++show id++":Ellipse}"
shallowShowPres (RowP id rf press)    = "{"++show id++":RowP, #children="++show (length press)++"}"
shallowShowPres (ColP id rf f press)    = "{"++show id++":ColP, f= "++show f++", #children="++show (length press)++"}"
shallowShowPres (OverlayP d id press)  = "{"++show id++":Overlay, dir= "++show d++", #children="++show (length press)++"}"
shallowShowPres (FormatterP  id press)  = "{"++show id++":Formatter, #children="++show (length press)++"}"
shallowShowPres (GraphP id _ _ _ _ press)  = "{"++show id++":Graph, #children="++show (length press)++"}"
shallowShowPres (VertexP _ _ x y _  pres)  = "{"++show id++":Vertex, x="++show x++",y="++show y++"}"
shallowShowPres (WithP ar pres)       = "{WithP}"
shallowShowPres (StructuralP id pres) = "{"++show id++":StructuralP}"
shallowShowPres (ParsingP id p l pres)    = "{"++show id++":ParsingP}"
shallowShowPres (LocatorP loc pres)   = "{LocatorP}"
shallowShowPres (TagP loc pres)   = "{TagP}"
shallowShowPres (ArrangedP)           = "ArrangedP" -- ++show pres
shallowShowPres _                     = "<<<presentation without show>>>"

getChildrenP :: (Show node, Show token) => PresentationBase doc enr node clip token level -> [PresentationBase doc enr node clip token level]
getChildrenP (EmptyP id)           = []
getChildrenP (StringP id str)      = []
getChildrenP (TokenP id str)      = []
getChildrenP (ImageP id str _)       = []
getChildrenP (PolyP id _ _ _)        = []
getChildrenP (RectangleP id _ _ _ _) = []
getChildrenP (EllipseP id _ _ _ _)   = []
getChildrenP (RowP id rf press)    = press
getChildrenP (ColP id rf _ press)    = press
getChildrenP (OverlayP _  id press)  = press
getChildrenP (FormatterP  id press) = press
getChildrenP (GraphP id _ _ _ _ press) = press
getChildrenP (VertexP _ _ x y _  pres) = [pres]
getChildrenP (WithP ar pres)       = [pres]
getChildrenP (StructuralP id pres) = [pres]
getChildrenP (ParsingP id p l pres)    = [pres]
getChildrenP (LocatorP loc pres)   = [pres]
getChildrenP (TagP _ pres)   = [pres]
getChildrenP (ArrangedP)           = []
getChildrenP pres                  = debug Err ("PresTypes.getChildren: unhandled presentation: "++shallowShowPres pres) []

getChildP :: (Show node, Show token) => PresentationBase doc enr node clip token level -> PresentationBase doc enr node clip token level
getChildP pres = case getChildrenP pres of
                  [child] -> child
                  _       -> debug Err ("PresTypes.getChild: not a single-child presentation: "++shallowShowPres pres) $ EmptyP NoIDP

setChildrenP :: (Show node, Show token) => [PresentationBase doc enr node clip token level] -> PresentationBase doc enr node clip token level -> PresentationBase doc enr node clip token level
setChildrenP [] pres@(EmptyP id)           = pres
setChildrenP [] pres@(StringP id str)      = pres
setChildrenP [] pres@(TokenP id str)      = pres
setChildrenP [] pres@(ImageP id str _)     = pres
setChildrenP [] pres@(PolyP id _ _ _)      = pres
setChildrenP [] pres@(RectangleP id _ _ _ _) = pres
setChildrenP [] pres@(EllipseP id _ _ _ _)   = pres
setChildrenP press' (RowP id rf _)     = RowP id rf press'
setChildrenP press' (ColP id rf f _)     = ColP id rf f press'
setChildrenP press' (OverlayP  id d _)   = OverlayP id d press'
setChildrenP press' (FormatterP  id _) = FormatterP id press'
setChildrenP press' (GraphP id d w h es _) = GraphP id d w h es press'
setChildrenP [pres'] (VertexP id vid x y ol _) = VertexP id vid x y ol pres'
setChildrenP [pres'] (WithP ar _)       = WithP ar pres'
setChildrenP [pres'] (StructuralP id _) = StructuralP id pres'
setChildrenP [pres'] (ParsingP id p l _)    = ParsingP id p l pres'
setChildrenP [pres'] (LocatorP loc _)   = LocatorP loc pres'
setChildrenP [pres'] (TagP tag _)   = TagP tag pres'
setChildrenP []      (ArrangedP)        = ArrangedP
setChildrenP press'  pres                  = debug Err ("PresTypes.setChildrenP: unhandled case " ++ show (length press') ++ ", " ++ shallowShowPres pres) pres


-- overlays: do they need a ref that says which element is the first, or in what order its elts should be parsed?
-- or is this always the order in which they appear on the screen? (== order of child list)
-- for now, the overlay can only have focus or be parsed in its head element.
{-

focus or parsing in overlay is more logical on last elt instead of first.

However, squigglies might be in front, just as boxes marking an area of the presentation. Some way of specifying
the main presentation is desirable. Pointing must also be smart enough to select the thing that was pointed at,
so in overlays with several pieces of text, both can be selected, but because a rectangle in front of a
presentation is as big as the presentation, it will always get the focus in that way.


-}





-- String has no reference, it would be rather useless, but if String is a row of characters, then it  
-- it could be logical in some cases



-- lineWidth should be an attribute here
data Inherited doc enr node clip token = Inh { font :: Font
                     , textColor :: Color, lineColor :: Color, fillColor, backgroundColor :: Color
                     , mouseDown :: Maybe (Wrapped doc enr node clip token)
                     , inheritablePopupMenuItems :: [ PopupMenuItem doc enr node clip token ]
                     , localPopupMenuItems :: [ PopupMenuItem doc enr node clip token ]
		     , assignedWidth, assignedHeight :: Int
		     , assignedVRef, assignedHRef :: Int} deriving Show
data Synthesized = Syn { vRef, hRef, minWidth, minHeight :: Int
                       , hStretch, vStretch :: Bool
		       , finalWidth, finalHeight :: Int
		       , finalVRef, finalHRef :: Int
		       } deriving Show

type AttrRule doc enr node clip token = (Inherited doc enr node clip token, Synthesized) -> (Inherited doc enr node clip token, Synthesized)

idP :: (Show node, Show token) => PresentationBase doc enr node clip token level -> IDP
idP (EmptyP id)           = id
idP (StringP id _)        = id
idP (TokenP id _)        = id
idP (ImageP id str _)       = id
idP (PolyP id _ _ _)        = id
idP (RectangleP id _ _ _ _) = id
idP (EllipseP id _ _ _ _)   = id
idP (RowP id _ _)         = id
idP (ColP id _ _ _)       = id
idP (OverlayP id _ press)  = id
idP (WithP ar pres)       = idP pres
idP (StructuralP id pres) = id
idP (ParsingP id p l pres)    = id
idP (LocatorP loc pres)   = idP pres
idP (TagP _ pres)   = idP pres
idP (GraphP id _ _ _ _ _)  = id
idP (VertexP id _ _ _ _ _) = id
idP (FormatterP id _)     = id
idP pres              = debug Err ("PresTypes.idP: unhandled presentation "++show pres) NoIDP


emptyInh = Inh defaultFont black black black black Nothing [] [] 0 0 0 0
emptySyn = Syn 0 0 0 0 False False 0 0 0 0

type UpdateDoc doc clip = DocumentLevel doc clip -> DocumentLevel doc clip

type PopupMenuItem doc enr node clip token = (String, Wrapped doc enr node clip token)

data PathPres = PathP [Int] Int
              | NoPathP deriving (Show, Eq, Ord)

data FocusPres = FocusP PathPres PathPres
               | NoFocusP deriving Show

fromP (FocusP from _) = from
fromP NoFocusP        = NoPathP

toP (FocusP _ to) = to
toP NoFocusP      = NoPathP

focusP from@(PathP _ _) to@(PathP _ _) = FocusP from to
focusP _ _                             = NoFocusP





-- TODO: add style to rectangles and images in presentation.
-- returns the document update function associated with the presentation at path

