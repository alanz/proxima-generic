ghci ../src/main/Main.hs  -fglasgow-exts -fallow-undecidable-instances -package lang -package wx -i../src/evaluation -i../src/presentation -i../src/layout -i../src/arrangement -i../src/rendering -i../src/main -i../src/common                                              -cpp -fgenerics -i../../parsec -i../../lvm/src/lib/common:../../lvm/src/lib/common/ghc:../../lvm/src/lib/lvm:../../lvm/src/lib/asm:../../lvm/src/lib/core -i../../heliumNT/src/syntax:../../heliumNT/src/parser:../../heliumNT/src/main:../../heliumNT/src/utils:../../heliumNT/src/modulesystem:../../heliumNT/src/staticanalysis/constraints:../../heliumNT/src/staticanalysis/inferencers:../../heliumNT/src/staticanalysis/inferencers/typingstrategies:../../heliumNT/src/staticanalysis/solvers:../../heliumNT/src/staticanalysis/solvers/typegraph:../../heliumNT/src/staticanalysis/solvers/typegraphheuristics:../../heliumNT/src/staticanalysis/messages:../../heliumNT/src/staticanalysis/staticchecks:../../heliumNT/src/staticanalysis/types:../../heliumNT/src/codegeneration -fallow-overlapping-instances