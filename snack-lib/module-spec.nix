# Functions related to module specs
{ lib
, callPackage
}:

with (callPackage ./modules.nix {});
with (callPackage ./package-spec.nix {});
with (callPackage ./lib.nix {});

rec {
    makeModuleSpec =
    modName:
    modImports:
    modFiles:
    modDirs:
    modBase:
    modDeps:
    modExts:
    modGhcOpts:
    { moduleName = modName;

      # local module imports, i.e. not part of an external dependency
      moduleImports = modImports;

      moduleFiles = modFiles;
      moduleDirectories = modDirs;
      moduleBase = modBase;
      moduleDependencies =
        if builtins.isList modDeps
        then modDeps
        else abort "module dependencies should be a list";
      moduleGhcOpts = modGhcOpts;
      moduleExtensions = modExts;
    };


    moduleSpecFold =
      { baseByModuleName
      , filesByModuleName
      , dirsByModuleName
      , depsByModuleName
      , extsByModuleName
      , ghcOptsByModuleName
      }:
      result:
    let
      modImportsNames = modName:
        lib.lists.filter
          (modName': ! builtins.isNull (baseByModuleName modName'))
          (listModuleImports baseByModuleName extsByModuleName modName);
    in
      # TODO: DFS instead of Fold
      { f = modName:
          { "${modName}" =
          makeModuleSpec
            modName
            (map (mn: result.${mn}) (modImportsNames modName))
            (filesByModuleName modName)
            (dirsByModuleName modName)
            (baseByModuleName modName)
            (depsByModuleName modName)
            (extsByModuleName modName)
            (ghcOptsByModuleName modName);
          };
        empty = {} ;
        reduce = a: b: a // b;
        elemLabel = lib.id;
        elemChildren = modImportsNames;
      };

  # Takes a package spec and returns (modSpecs -> Fold)
  modSpecFoldFromPackageSpec = pkgSpec:
      let
        baseByModuleName = modName:
          let res = pkgSpecAndBaseByModuleName pkgSpec modName;
          in if res == null then null else res.base;
        depsByModuleName = modName:
          (pkgSpecByModuleName
            pkgSpec
            (abort "asking dependencies for external module: ${modName}")
            modName).packageDependencies
            modName
          ;
        extsByModuleName = modName:
          (pkgSpecByModuleName
            pkgSpec
            (abort "asking extensions for external module: ${modName}")
            modName).packageExtensions;
        ghcOptsByModuleName = modName:
          (pkgSpecByModuleName
            pkgSpec
            (abort "asking ghc options for external module: ${modName}")
            modName).packageGhcOpts;
      in
        moduleSpecFold
          { baseByModuleName = baseByModuleName;
            filesByModuleName = pkgSpec.packageExtraFiles;
            dirsByModuleName = pkgSpec.packageExtraDirectories;
            depsByModuleName = depsByModuleName;
            extsByModuleName = extsByModuleName;
            ghcOptsByModuleName = ghcOptsByModuleName;
          };
}
