-- import Distribution.Simple
-- main = defaultMain

-- From http://www.cs.uu.nl/wiki/HUT/AttributeGrammarManual#Building_AG_files_with_Cabal
import Distribution.Simple (defaultMainWithHooks)
import Distribution.Simple.UUAGC (uuagcLibUserHook)
import UU.UUAGC (uuagc)

main = defaultMainWithHooks (uuagcLibUserHook uuagc)
