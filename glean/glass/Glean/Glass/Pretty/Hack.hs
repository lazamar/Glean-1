{-
  Copyright (c) Meta Platforms, Inc. and affiliates.
  All rights reserved.

  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree.
-}

{-# LANGUAGE TypeApplications, ApplicativeDo #-}

module Glean.Glass.Pretty.Hack
  ( prettyHackSignature
    -- for testing
  , prettyDecl
  , ByteSpan(..)
  , Decl(..)
  , Name(..)
  , Qual(..)
  , QualName(..)
  , FunctionMod(..)
  , PropertyMod(..)
  , ClassMod(..)
  , MethodMod(..)
  , Abstract(..)
  , Final(..)
  , Visibility(..)
  , Static(..)
  , Async(..)
  , Signature (..)
  , HackType(..)
  , ReturnType(..)
  , DefaultValue(..)
  , Inout(..)
  , Variadic(..)
  , Parameter(..)
  , Variance(..)
  , Reify(..)
  , TypeParameter(..)
  , Constraint(..)
  , ConstraintKind(..)
  , Container(..)
  , EnumKind(..)
  , EnumConstraint(..)
  , TypeConstKind(..)
  , Transparency(..)
  ) where

import qualified Glean
import Glean.Angle as Angle
import qualified Glean.Haxl.Repos as Glean
import qualified Glean.Schema.Hack.Types as Hack
import qualified Glean.Schema.Src.Types as Src
import Glean.Schema.CodeHack.Types as Hack ( Entity(..) )
import qualified Glean.Schema.Code.Types as Code
import qualified Glean.Schema.CodemarkupTypes.Types as Code
import qualified Glean.Schema.Codemarkup.Types as Code
import Glean.Glass.Utils
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text.Prettyprint.Doc
import Data.Text.Prettyprint.Doc.Render.Text (renderStrict)
import Data.Text (Text)
import qualified Data.Text as Text
import Control.Monad.Trans.Maybe (MaybeT (..))
import Control.Monad
import Control.Monad.Extra
import Control.Monad.Trans (MonadTrans(lift))
import Control.Monad.Trans.Writer.Strict
import Data.List as List
import Glean.Glass.SymbolId ( toSymbolId )
import Glean.Glass.Types ( SymbolId(..), RepoName(..) )
import Glean.Glass.Base ( GleanPath(..) )
import Glean.Glass.Path ( fromGleanPath )
import Glean.Util.ToAngle ( ToAngle(toAngle) )

-- Pretty-printer annotations for Doc or SimpleDocStream
-- Used to collect xrefs bytespan in pretty-printed signatures
type Ann = Maybe Hack.Declaration

prettyHackSignature
  :: LayoutOptions
  -> RepoName
  -> Hack.Entity
  -> Glean.RepoHaxl u w (Maybe (SimpleDocStream (Maybe SymbolId)))
prettyHackSignature opts repo (Hack.Entity_decl d) = runMaybeT $ do
  docStream <- layoutSmart opts . prettyDecl opts <$> decl d
  let docStreamSymbol = sequence $ reAnnotateS (declToSymbolId repo) docStream
  MaybeT $ Just <$> docStreamSymbol
prettyHackSignature _ _ Hack.Entity_EMPTY = return Nothing

-- Turn declaration to symbol ids
-- This requires a query to Code.EntityLocation to gather
-- the path to an entity, needed for constructing a SymbolId
declToSymbolId
  :: RepoName
  -> Ann
  -> Glean.RepoHaxl u w (Maybe SymbolId)
declToSymbolId _repo Nothing = return Nothing
declToSymbolId repo (Just decl) = runMaybeT $ do
  let entity = Code.Entity_hack (Hack.Entity_decl decl)
  let entityAngle = alt @"hack" (alt @"decl" (toAngle decl))
  Code.EntityLocation{..} <- maybeT $ fetchDataRecursive $
    angleEntityLocation entityAngle
  Code.EntityLocation_key{..} <- liftMaybe entityLocation_key
  let Code.Location{..} = entityLocation_key_location
  path <- MaybeT (Just . GleanPath <$> Glean.keyOf location_file)
  MaybeT $ Just <$> toSymbolId (fromGleanPath repo path) entity

newtype Name = Name Text
newtype Qual = Qual [Text]
newtype QualName = QualName ([Text], Text)

-- Hack modifier orderings are not as strict as this but since we want
-- to print them in some consistent ordering we enforce the most popular
newtype FunctionMod = FunctionMod Async
data ClassMod    = ClassMod Abstract Final
data MethodMod   = MethodMod Abstract Final Visibility Static Async
data PropertyMod   = PropertyMod Abstract Final Visibility Static

data Abstract = Abstract | NotAbstract deriving (Eq)
data Final = Final | NotFinal deriving (Eq)
data Visibility = Public | Protected | Private | Internal deriving (Eq)
data Static = Static | NotStatic deriving (Eq)
data Async = Async | NotAsync deriving (Eq)

data ByteSpan = ByteSpan
  { start :: {-# UNPACK #-}!Int
  , length :: {-# UNPACK #-}!Int
  }
type XRefs = [(Hack.Declaration, ByteSpan)]
newtype HackType = HackType { unHackType :: Text }
newtype ReturnType = ReturnType { unReturnType :: Text }
newtype DefaultValue = DefaultValue Text
data Inout = Inout
data Variadic = Variadic
data Parameter
  = Parameter Name HackType (Maybe Inout)
      (Maybe Variadic) (Maybe DefaultValue) XRefs
data Variance = Contravariant | Covariant | Invariant
data Reify = Erased | Reified | SoftReified
data ConstraintKind = As | Equal | Super
data Constraint = Constraint ConstraintKind HackType
data TypeParameter = TypeParameter Name Variance Reify [Constraint] [UserAttr]
data UserAttr = UserAttr Name [Text]
newtype Context = Context { _unContext :: Text }
data Signature = Signature ReturnType [TypeParameter] [Parameter]
  (Maybe [Context]) XRefs
data Container
  = ClassContainer | InterfaceContainer | TraitContainer | EnumContainer
  deriving Eq
data EnumKind = IsClass | Regular
data EnumConstraint = EnumBase HackType | Constrained HackType HackType
data TypeConstKind = IsAbstract | Concrete | PartiallyAbstract
data Transparency = Newtype_ | Type_

data Decl
  = ClassConst Name
  | Enum QualName EnumKind EnumConstraint
  | Trait QualName [TypeParameter]
  | Class ClassMod QualName [TypeParameter]
  | Interface QualName [TypeParameter]
  | Enumerator QualName Name
  | Function FunctionMod QualName Signature
  | GlobalConst QualName
  | Namespace Qual
  | Method MethodMod Container Name Signature
  | Property PropertyMod Container Name HackType
  | TypeConst Name TypeConstKind
  | Typedef QualName [TypeParameter] Transparency
  | Module Name

prettyDecl :: LayoutOptions -> Decl -> Doc Ann
prettyDecl _ (ClassConst name) =
  "const" <+> ppName name
prettyDecl _ (Module name) =
  "module" <+> ppName name
prettyDecl _ (Enum name Regular (EnumBase ty1)) =
  "enum" <+> ppQualName name <+> ":" <+> ppType ty1
prettyDecl _ (Enum name Regular (Constrained ty1 ty2)) =
  "enum" <+> ppQualName name <+> ":" <+> ppConstraintTypes ty1 ty2
prettyDecl _ (Enum name IsClass _) =
  "enum" <+> "class" <+> ppQualName name
prettyDecl _ (Trait name typeParams) =
  "trait" <+> ppQualName name <> ppTypeParams typeParams
prettyDecl _ (Class modifiers name typeParams) =
  ppClassModifiers modifiers <+> ppQualName name <> ppTypeParams typeParams
prettyDecl _ (Interface name typeParams) =
  "interface" <+> ppQualName name <> ppTypeParams typeParams
prettyDecl _ (Enumerator enum name) =
  ppQualName enum <> "::" <> ppName name
prettyDecl opts (Function modifiers name sig) =
  ppSignature opts (ppFunctionModifiers modifiers <+> ppQualName name) sig
prettyDecl _ (GlobalConst name) =
  "const" <+> ppQualName name
prettyDecl _ (Namespace name) =
  "namespace" <+> ppQual name
prettyDecl opts (Method modifiers container name sig) =
  ppSignature opts (ppMethodModifiers container modifiers <+> ppName name) sig
prettyDecl _ (Property modifiers container name mhacktype) =
  ppPropertyModifiers container modifiers <+> ppType mhacktype <+> ppName name
prettyDecl _ (TypeConst name IsAbstract) =
  "abstract" <+> "const" <+> "type" <+> ppName name
prettyDecl _ (TypeConst name _) =
  "const" <+> "type" <+> ppName name
prettyDecl _ (Typedef name typeParams Type_) =
  "type" <+> ppQualName name <> ppTypeParams typeParams
prettyDecl _ (Typedef name typeParams Newtype_) =
  "newtype" <+> ppQualName name <> ppTypeParams typeParams

ppName :: Name -> Doc Ann
ppName (Name n) = pretty n
ppQualName :: QualName -> Doc Ann
ppQualName (QualName ([], name)) =
  pretty name
ppQualName (QualName (namespace, name)) =
  surround "\\" (ppQual (Qual namespace)) (pretty name)
ppQual :: Qual -> Doc Ann
ppQual (Qual namespace) =
  concatWith (surround "\\") (pretty <$> namespace)

ppFunctionModifiers :: FunctionMod -> Doc Ann
ppFunctionModifiers (FunctionMod async) =
  fillSep $ execWriter $ do
    when (async==Async) $ tell ["async"]
    tell ["function"]

ppClassModifiers :: ClassMod -> Doc Ann
ppClassModifiers (ClassMod abstract final) =
  fillSep $ execWriter $ do
    when (abstract==Abstract) $ tell ["abstract"]
    when (final==Final) $ tell ["final"]
    tell ["class"]

ppSignature :: LayoutOptions -> Doc Ann -> Signature -> Doc Ann
ppSignature opts head (Signature returnType typeParams params ctxs xrefs) =
    if fitsOnOneLine then
      onelineSig
    else
      multilineSig
  where
    onelineTypeParams = if null typeParams then emptyDoc else cat
      [ "<"
      , sep $ punctuate "," (map ppTypeParam typeParams)
      , ">"
      ]
    onelineArgs = if null params then "()" else
      parens (hsep $ punctuate comma (map ppParameter params))
    onelineSig = nest 4 $ head <> fillCat
      [ onelineTypeParams
      , onelineArgs
      , ppContexts ctxs
      , ":" <+> ppReturnType returnType xrefs
      ]
    multilineTypeParams = if null typeParams then emptyDoc else vcat
        [ nest 4 $ vcat
          [ "<"
          , vcat $ map ((<> ",") . ppTypeParam) typeParams
          ]
        , ">"
        ]
    multilineArgs = vcat
      [ nest 4 (vcat $
        "("
        : map ((<> ",") . ppParameter) params
        )
      , ")"
      ]
    multilineSig = head
      <> multilineTypeParams
      <> multilineArgs
      <> nest 4 (
        ppContexts ctxs
        <> ":"
        <+> ppReturnType returnType xrefs
      )
    paramsText = renderStrict $ layoutSmart opts onelineSig
    fitsOnOneLine = not containsNewline
    containsNewline = Text.any (== '\n') paramsText

ppTypeParams :: [TypeParameter] -> Doc Ann
ppTypeParams typeParams | null typeParams = emptyDoc
ppTypeParams typeParams = cat
  [ nest 4 $ cat
    [ "<", sep $ punctuate "," (map ppTypeParam typeParams)]
  , ">"
  ]

--
-- Lots of interesting syntax for type parameters
-- https://docs.hhvm.com/hack/generics/introduction
--
ppTypeParam :: TypeParameter -> Doc Ann
ppTypeParam (TypeParameter name variance reify constraints userAttrs) = hcat
  [ ppAttrs userAttrs -- attributes
  , ppReified reify -- reify keyword
  , ppVariance variance -- then the variance markers
  , ppName name -- then the type param name
  , hsep (map ppConstraint constraints) -- and any constraints
  ]

-- User attributes on type parameters, including the reification attributes
ppAttrs :: [UserAttr] -> Doc Ann
ppAttrs attrs = case attrs of
  [] -> emptyDoc
  _ -> hcat ["<<", hsep (punctuate comma (map ppAttr attrs)), ">> "]

-- https://docs.hhvm.com/hack/attributes/introduction
ppAttr :: UserAttr -> Doc Ann
-- e.g. __Memoize
ppAttr (UserAttr name []) = ppName name
-- __Deprecated("foo")
-- <<Contributors("John Doe", keyset["ORM Team", "Core Library Team"])>>
ppAttr (UserAttr name args)
  = ppName name <>
      parens (hsep (punctuate comma (map pretty args)))

-- Reified generics
-- https://docs.hhvm.com/hack/reified-generics/reified-generics
ppReified :: Reify -> Doc Ann
ppReified SoftReified = "reify "
ppReified Reified = "reify "
ppReified _ = emptyDoc

--
-- Variance markers on type parameters
-- See https://docs.hhvm.com/hack/generics/variance
--
ppVariance :: Variance -> Doc Ann
ppVariance Covariant = "+"
ppVariance Contravariant = "-"
ppVariance _ = emptyDoc

--
-- Generic type parameter constraint syntax
-- See https://docs.hhvm.com/hack/generics/type-constraints
--
ppConstraint :: Constraint -> Doc Ann
ppConstraint (Constraint kind ty) = hcat
  [ case kind of
      Equal -> " = "
      As -> " as "
      Super -> " super "
  , ppType ty
  ]

ppTypeXRefs :: HackType -> XRefs -> Doc Ann
ppTypeXRefs (HackType t) xrefs =
  let spans = fmap (\(ann, ByteSpan{..}) -> (ann, start, length)) xrefs
      fragments = splitString t spans in
  mconcat $ (\(frag, ann) -> annotate ann $ pretty frag) <$> fragments

ppType :: HackType -> Doc Ann
ppType (HackType t) = pretty t

ppReturnType :: ReturnType -> XRefs -> Doc Ann
ppReturnType (ReturnType t) xrefs = ppTypeXRefs (HackType t) xrefs

ppParameter :: Parameter -> Doc Ann
ppParameter (Parameter name typeName inout variadic defaultValue xrefs) =
  nest 4 $ sep $ execWriter $ do
    whenJust inout $ tell . ppInout
    tell [ppTypeXRefs typeName xrefs]
    case variadic of
      Just Variadic -> tell [hcat ["...", ppName name]]
      Nothing ->  tell [ppName name]
    whenJust defaultValue $ tell . pure . ppDefaultValue typeName

-- Contexts can be parameterised, empty, missing. or a simple list
-- https://docs.hhvm.com/hack/contexts-and-capabilities/introduction
ppContexts :: Maybe [Context] -> Doc Ann
ppContexts Nothing = emptyDoc
ppContexts (Just []) = brackets emptyDoc
ppContexts (Just ctxs) = brackets $ hsep (punctuate comma (map ppContext ctxs))

ppContext :: Context -> Doc Ann
ppContext (Context ctx) = pretty ctx

ppDefaultValue :: HackType -> DefaultValue -> Doc Ann
ppDefaultValue typeName (DefaultValue v) = "=" <+>
  case typeName of -- work around for type-sensitive quoting
    HackType ty
      | ty `elem` ["string", "?string"], v /= "null" -> squotes (pretty v)
    _ -> pretty v

ppInout :: Inout -> [Doc Ann]
ppInout Inout = ["inout"]

ppConstraintTypes :: HackType -> HackType -> Doc Ann
ppConstraintTypes ty1 ty2 = ppType ty1 <+> "as" <+> ppType ty2

ppMethodModifiers :: Container -> MethodMod -> Doc Ann
ppMethodModifiers container (MethodMod abstract final visibility static async) =
  fillSep $ execWriter $ do
    when
      (  abstract == Abstract
      && container /= InterfaceContainer
      ) $ tell ["abstract"]
    when (final==Final) $ tell ["final"]
    tell $ pure $ case visibility of
      Public -> "public"
      Protected -> "protected"
      Private -> "private"
      Internal -> "internal"
    when (static==Static) $ tell ["static"]
    when (async==Async) $ tell ["async"]
    tell ["function"]

ppPropertyModifiers :: Container -> PropertyMod -> Doc Ann
ppPropertyModifiers container (PropertyMod abstract final visibility static) =
  fillSep $ execWriter $ do
    when
      (  abstract == Abstract
      && container /= InterfaceContainer
      ) $ tell ["abstract"]
    when (final==Final) $ tell ["final"]
    tell $ pure $ case visibility of
      Public -> "public"
      Protected -> "protected"
      Private -> "private"
      Internal -> "internal"
    when (static==Static) $ tell ["static"]

decl :: Hack.Declaration -> Glean.MaybeTRepoHaxl u w Decl
decl (Hack.Declaration_classConst Hack.ClassConstDeclaration{..}) = do
  Hack.ClassConstDeclaration_key{..} <- liftMaybe classConstDeclaration_key
  name <- liftMaybe $ Hack.name_key classConstDeclaration_key_name
  pure $ ClassConst $ Name name
decl (Hack.Declaration_container container) = containerDecl container
decl (Hack.Declaration_enumerator Hack.Enumerator{..}) = do
  Hack.Enumerator_key{..} <- liftMaybe enumerator_key
  Hack.EnumDeclaration{..} <- pure enumerator_key_enumeration
  Hack.EnumDeclaration_key{..} <- liftMaybe enumDeclaration_key
  enum <- qName enumDeclaration_key_name
  name <- liftMaybe $ Hack.name_key enumerator_key_name
  pure $ Enumerator (QualName enum) $ Name name
decl (Hack.Declaration_function_ decl@Hack.FunctionDeclaration{..}) = do
  Hack.FunctionDeclaration_key{..} <- liftMaybe functionDeclaration_key
  Hack.FunctionDefinition{..} <- maybeT $ fetchDataRecursive $
    angleFunctionDefinition (Angle.factId (Glean.getId decl))
  name <- qName functionDeclaration_key_name
  def <- liftMaybe functionDefinition_key
  let typeParams = Hack.functionDefinition_key_typeParams def
  let sign = Hack.functionDefinition_key_signature def
  pure $ Function (modifiersForFunction def) (QualName name)
    (toSignature typeParams sign)
decl (Hack.Declaration_module Hack.ModuleDeclaration{..}) = do
  Hack.ModuleDeclaration_key{..} <- liftMaybe moduleDeclaration_key
  name <- liftMaybe $ Hack.name_key moduleDeclaration_key_name
  pure $ Module $ Name name
decl (Hack.Declaration_globalConst Hack.GlobalConstDeclaration{..}) = do
  Hack.GlobalConstDeclaration_key{..} <- liftMaybe globalConstDeclaration_key
  name <- qName globalConstDeclaration_key_name
  pure $ GlobalConst $ QualName name
decl (Hack.Declaration_namespace_ Hack.NamespaceDeclaration{..}) = do
  Hack.NamespaceDeclaration_key{..} <- liftMaybe namespaceDeclaration_key
  name <- namespaceQName $ Just namespaceDeclaration_key_name
  pure $ Namespace $ Qual name
decl (Hack.Declaration_method decl@Hack.MethodDeclaration{..}) = do
  Hack.MethodDeclaration_key{..} <- liftMaybe methodDeclaration_key
  Hack.MethodDefinition{..} <- maybeT $ fetchDataRecursive $
    angleMethodDefinition (Angle.factId (Glean.getId decl))
  name <- liftMaybe $ Hack.name_key methodDeclaration_key_name
  def <- liftMaybe methodDefinition_key
  let typeParams = Hack.methodDefinition_key_typeParams def
  let sig = Hack.methodDefinition_key_signature def
  let container = containerKind methodDeclaration_key_container
  pure $ Method (modifiersForMethod def) container (Name name)
    (toSignature typeParams sig)
decl (Hack.Declaration_property_ prop@Hack.PropertyDeclaration{..}) = do
  Hack.PropertyDeclaration_key{..} <- liftMaybe propertyDeclaration_key
  Hack.PropertyDefinition{..} <- maybeT $ fetchDataRecursive $
    predicate @Hack.PropertyDefinition $
      rec $
        field @"declaration"
          (Angle.asPredicate $ Angle.factId $ Glean.getId prop)
      end
  def <- liftMaybe propertyDefinition_key
  let type_ = Hack.propertyDefinition_key_type def
  name <- liftMaybe $ Hack.name_key propertyDeclaration_key_name
  let container = containerKind propertyDeclaration_key_container
  pure $ Property (modifiersForProperty def) container (Name name)
   (toType type_)
decl (Hack.Declaration_typeConst decl@Hack.TypeConstDeclaration{..}) = do
  Hack.TypeConstDeclaration_key{..} <- liftMaybe typeConstDeclaration_key
  hackTypeConstKind <- maybeT $ fetchData $
    angleTypeConstDefinition (Angle.factId (Glean.getId decl))
  let typeConstKind = case hackTypeConstKind of
        Hack.TypeConstKind_Abstract -> IsAbstract
        Hack.TypeConstKind_Concrete -> Concrete
        Hack.TypeConstKind_PartiallyAbstract -> PartiallyAbstract
        Hack.TypeConstKind__UNKNOWN{} -> error "unexpected typeconst kind"
  name <- liftMaybe $ Hack.name_key typeConstDeclaration_key_name
  pure $ TypeConst (Name name) typeConstKind
decl (Hack.Declaration_typedef_ decl@Hack.TypedefDeclaration{..}) = do
  Hack.TypedefDeclaration_key{..} <- liftMaybe typedefDeclaration_key
  (typedefTypeParams, isTransparent) <- maybeT $ fetchDataRecursive $
    angleTypedefDefinition (Angle.factId (Glean.getId decl))
  name <- qName typedefDeclaration_key_name
  let typeParams = map toTypeParameter typedefTypeParams
      isNewtype = if isTransparent then Type_ else Newtype_
  pure $ Typedef (QualName name) typeParams isNewtype
decl Hack.Declaration_EMPTY = MaybeT (return Nothing)

containerDecl :: Hack.ContainerDeclaration -> Glean.MaybeTRepoHaxl u w Decl
containerDecl (Hack.ContainerDeclaration_enum_
      decl@Hack.EnumDeclaration{..}) = do
    Hack.EnumDeclaration_key{..} <- liftMaybe enumDeclaration_key
    (enumBase,enumConstraint,isClass) <- maybeT $ fetchDataRecursive $
      angleEnumDefinition (Angle.factId (Glean.getId decl))
    let enumKind = if isClass then IsClass else Regular
    let constraint =  case enumConstraint of
          Nothing -> EnumBase (toType1 enumBase)
          Just ty -> Constrained (toType1 enumBase) (toType1 ty)
    name <- qName enumDeclaration_key_name
    pure $ Enum (QualName name) enumKind constraint
containerDecl
  (Hack.ContainerDeclaration_trait decl@Hack.TraitDeclaration{..}) = do
    Hack.TraitDeclaration_key{..} <- liftMaybe traitDeclaration_key
    traitTypeParams <- maybeT $ fetchDataRecursive $
      angleTraitDefinition (Angle.factId (Glean.getId decl))
    name <- qName traitDeclaration_key_name
    let typeParams = map toTypeParameter traitTypeParams
    pure $ Trait (QualName name) typeParams
containerDecl
  (Hack.ContainerDeclaration_class_ decl@Hack.ClassDeclaration{..}) = do
    Hack.ClassDeclaration_key{..} <- liftMaybe classDeclaration_key
    (isAbstract, isFinal, classTypeParams) <- maybeT $ fetchDataRecursive $
      angleClassDefinition (Angle.factId (Glean.getId decl))
    name <- qName classDeclaration_key_name
    let typeParams = map toTypeParameter classTypeParams
    pure $ Class (modifiersForClass isAbstract isFinal) (QualName name)
      typeParams
containerDecl
  (Hack.ContainerDeclaration_interface_ decl@Hack.InterfaceDeclaration{..}) = do
    Hack.InterfaceDeclaration_key{..} <- liftMaybe interfaceDeclaration_key
    interTypeParams <- maybeT $ fetchDataRecursive $
      angleInterfaceDefinition (Angle.factId (Glean.getId decl))
    name <- qName interfaceDeclaration_key_name
    let typeParams = map toTypeParameter interTypeParams
    pure $ Interface (QualName name) typeParams
containerDecl Hack.ContainerDeclaration_EMPTY = MaybeT (return Nothing)

containerKind
  :: Hack.ContainerDeclaration -> Container
containerKind Hack.ContainerDeclaration_enum_ {} = EnumContainer
containerKind Hack.ContainerDeclaration_trait {} = TraitContainer
containerKind Hack.ContainerDeclaration_class_ {} = ClassContainer
containerKind Hack.ContainerDeclaration_interface_ {} = InterfaceContainer
containerKind Hack.ContainerDeclaration_EMPTY = ClassContainer

qName :: Hack.QName -> Glean.MaybeTRepoHaxl u w ([Text], Text)
qName Hack.QName{..} = do
 Hack.QName_key{..} <- liftMaybe qName_key
 namespace <- namespaceQName qName_key_namespace_
 name <- liftMaybe $ Hack.name_key qName_key_name
 return (namespace, name)

namespaceQName :: Maybe Hack.NamespaceQName -> Glean.MaybeTRepoHaxl u w [Text]
namespaceQName Nothing = return []
namespaceQName (Just name) = do
  let Hack.NamespaceDeclaration_key{..} = Hack.NamespaceDeclaration_key name
  alias <- lift $ fetchDataRecursive $ predicate @Hack.GlobalNamespaceAlias $
      rec $
        field @"to"
          (Angle.asPredicate $ Angle.factId
          $ Glean.getId namespaceDeclaration_key_name)
      end
  case alias of
    Just Hack.GlobalNamespaceAlias
      { globalNamespaceAlias_key = Just Hack.GlobalNamespaceAlias_key
          { globalNamespaceAlias_key_from=from
          }
      } -> do
        name <- liftMaybe $ Hack.name_key from
        return [name]
    _ -> return $ fromMaybe [] $ namespaceQNameInner (Just name) []
  where
    namespaceQNameInner
      :: Maybe Hack.NamespaceQName -> [Text] -> Maybe [Text]
    namespaceQNameInner Nothing children = Just children
    namespaceQNameInner (Just Hack.NamespaceQName{..}) children = do
    Hack.NamespaceQName_key{..} <- namespaceQName_key
    parent <- Hack.name_key namespaceQName_key_name
    namespaceQNameInner namespaceQName_key_parent (parent:children)

modifiersForFunction :: Hack.FunctionDefinition_key -> FunctionMod
modifiersForFunction Hack.FunctionDefinition_key {..} =
  FunctionMod
    (if functionDefinition_key_isAsync then Async else NotAsync)

modifiersForClass :: Bool -> Bool -> ClassMod
modifiersForClass isAbstract isFinal =
  ClassMod
    (if isAbstract then Abstract else NotAbstract)
    (if isFinal then Final else NotFinal)

modifiersForMethod :: Hack.MethodDefinition_key -> MethodMod
modifiersForMethod Hack.MethodDefinition_key {..} =
  MethodMod
  (if methodDefinition_key_isAbstract then Abstract else NotAbstract)
  (if methodDefinition_key_isFinal then Final else NotFinal)
  (case methodDefinition_key_visibility of
    Hack.Visibility_Public -> Public
    Hack.Visibility_Protected -> Protected
    Hack.Visibility_Private -> Private
    Hack.Visibility_Internal -> Internal
    Hack.Visibility__UNKNOWN{} -> error "unexpected visibility"
  )
  (if methodDefinition_key_isStatic then Static else NotStatic)
  (if methodDefinition_key_isAsync then Async else NotAsync)

modifiersForProperty :: Hack.PropertyDefinition_key -> PropertyMod
modifiersForProperty Hack.PropertyDefinition_key {..} =
  PropertyMod
  (if propertyDefinition_key_isAbstract then Abstract else NotAbstract)
  (if propertyDefinition_key_isFinal then Final else NotFinal)
  (case propertyDefinition_key_visibility of
    Hack.Visibility_Public -> Public
    Hack.Visibility_Protected -> Protected
    Hack.Visibility_Private -> Private
    Hack.Visibility_Internal -> Internal
    Hack.Visibility__UNKNOWN{} -> error "unexpected visibility"
  )
  (if propertyDefinition_key_isStatic then Static else NotStatic)


-- Glass-side implementation of fbcode/glean/rts/prim.cpp:relSpansToAbs
relSpansToAbs :: [Src.RelByteSpan] -> [ByteSpan]
relSpansToAbs byteSpans = snd $ List.foldl' f (0, []) byteSpans
  where
    f (!start, acc) (Src.RelByteSpan offset length) =
      let off = fromIntegral (Glean.fromNat offset)
          len = fromIntegral (Glean.fromNat length)
          start' = start + off
      in (start', ByteSpan start' len : acc)

-- Extracts type and xrefs from a TypeInfo
-- XRefs are converted from relative spans (Glean representation)
-- to absolute (Glass representation)
-- If TypeInfo doesn't exist, returned type is overridden by provided
-- default.
toTypeAndXRefs :: Maybe Hack.Type -> Maybe Hack.TypeInfo -> (HackType, XRefs)
toTypeAndXRefs type_ typeInfo = case typeInfo of
  (Just (Hack.TypeInfo _ (Just (Hack.TypeInfo_key displayType hackXRefs)))) ->
    let f (Hack.XRef declaration ranges) = case declaration of
          Hack.XRefTarget_declaration decl ->
            Just ((\x -> (decl, x)) <$> relSpansToAbs ranges)
          _ -> Nothing
        xrefs = concat (mapMaybe f hackXRefs)
    in (toType $ Just displayType, xrefs)

  _ -> (toType type_, [])

toSignature :: [Hack.TypeParameter] -> Hack.Signature -> Signature
toSignature typeParams Hack.Signature{..} = case signature_key of
  Nothing -> Signature (ReturnType unknownType) [] [] Nothing []
  Just (Hack.Signature_key retType params mctxs retTypeInfo) ->
   let (type_, xrefs) = toTypeAndXRefs retType retTypeInfo
   in Signature
        (ReturnType (unHackType type_))
        (map toTypeParameter typeParams)
        (map toParameter params)
        (map toContext <$> mctxs)
        -- Maybe [] is used to distinguish default context from literal "[]"
        xrefs

toType :: Maybe Hack.Type -> HackType
toType Nothing = HackType unknownType
toType (Just (Hack.Type _ mkey)) = HackType $ fromMaybe unknownType mkey

toType1 :: Hack.Type -> HackType
toType1 (Hack.Type _ mkey) = HackType $ fromMaybe unknownType mkey

toTypeParameter :: Hack.TypeParameter -> TypeParameter
toTypeParameter
  (Hack.TypeParameter name variance reifyKind constraints attributes) =
    TypeParameter
    (toName name)
    (toVariance variance)
    (toReifyKind reifyKind)
    (map toConstraint constraints)
    (mapMaybe toAttribute attributes)

toAttribute :: Hack.UserAttribute -> Maybe UserAttr
toAttribute (Hack.UserAttribute _ Nothing) = Nothing
toAttribute (Hack.UserAttribute _ (Just
    (Hack.UserAttribute_key name params _))) =
  Just $ UserAttr (toName name) params

toContext :: Hack.Context_ -> Context
toContext (Hack.Context_ _ Nothing) = Context unknownType
toContext (Hack.Context_ _ (Just ctx)) = Context ctx'
  where
    -- There are only a few dozen contexts in use.
    -- Gronky auto-imported handling hack to get a short name
    --
    -- > [\HH\Contexts\leak_safe] -> [leak_safe]
    --
    -- If we switch to proper declarations and auto-import tables we can avoid
    -- the string handling here.
    ctx' | Just tidy <- Text.stripPrefix "\\HH\\Contexts\\" ctx = tidy
         | otherwise = ctx

toVariance :: Hack.Variance -> Variance
toVariance Hack.Variance_Invariant = Invariant
toVariance Hack.Variance_Contravariant = Contravariant
toVariance Hack.Variance_Covariant = Covariant
toVariance (Hack.Variance__UNKNOWN _) = Invariant

toReifyKind :: Hack.ReifyKind -> Reify
toReifyKind Hack.ReifyKind_Reified = Reified
toReifyKind Hack.ReifyKind_SoftReified = SoftReified
toReifyKind Hack.ReifyKind_Erased = Erased
toReifyKind (Hack.ReifyKind__UNKNOWN _) = Erased

toConstraint :: Hack.Constraint -> Constraint
toConstraint (Hack.Constraint kind ty) =
  Constraint (toConstraintKind kind) (toType $ Just ty)

toConstraintKind :: Hack.ConstraintKind -> ConstraintKind
toConstraintKind Hack.ConstraintKind_Equal = Equal
toConstraintKind Hack.ConstraintKind_As = As
toConstraintKind Hack.ConstraintKind_Super = Super
toConstraintKind (Hack.ConstraintKind__UNKNOWN _) = Equal

toParameter :: Hack.Parameter -> Parameter
toParameter (Hack.Parameter name mtype inout variadic mdefaultValue _ typeInfo) =
  let (type_, xrefs) = toTypeAndXRefs mtype typeInfo
  in Parameter
      (toName name)
      (HackType (unHackType type_))
      (if inout then Just Inout else Nothing)
      (if variadic then Just Variadic else Nothing)
      (DefaultValue <$> mdefaultValue)
      xrefs

toName :: Hack.Name -> Name
toName (Hack.Name _ mkey) = Name $ fromMaybe "(anonymous)" mkey

unknownType :: Text
unknownType = "<unknown-type>"

liftMaybe :: (MonadPlus m) => Maybe a -> m a
liftMaybe = maybe mzero return

maybeT :: (MonadTrans t, Monad m, MonadPlus (t m)) => m (Maybe b) -> t m b
maybeT act = lift act >>= liftMaybe

angleClassDefinition
  :: Angle Hack.ClassDeclaration -> Angle (Bool, Bool, [Hack.TypeParameter])
angleClassDefinition decl = vars $ \isAbstract isFinal typeParams ->
  tuple (isAbstract, isFinal, typeParams) `where_` [
    wild .= predicate @Hack.ClassDefinition (
      rec $
        field @"declaration" (Angle.asPredicate decl) $
        field @"isAbstract" isAbstract $
        field @"isFinal" isFinal $
        field @"typeParams" typeParams
      end)
  ]

angleTraitDefinition
  :: Angle Hack.TraitDeclaration -> Angle [Hack.TypeParameter]
angleTraitDefinition decl = var $ \typeParams ->
  typeParams `where_` [
    wild .= predicate @Hack.TraitDefinition (
      rec $
        field @"declaration" (Angle.asPredicate decl) $
        field @"typeParams" typeParams
      end)
  ]

angleInterfaceDefinition
  :: Angle Hack.InterfaceDeclaration -> Angle [Hack.TypeParameter]
angleInterfaceDefinition decl = var $ \typeParams ->
  typeParams `where_` [
    wild .= predicate @Hack.InterfaceDefinition (
      rec $
        field @"declaration" (Angle.asPredicate decl) $
        field @"typeParams" typeParams
      end)
  ]

angleTypedefDefinition
  :: Angle Hack.TypedefDeclaration -> Angle ([Hack.TypeParameter], Bool)
angleTypedefDefinition decl = vars $ \typeParams transparency ->
  tuple (typeParams, transparency) `where_` [
    wild .= predicate @Hack.TypedefDefinition (
      rec $
        field @"declaration" (Angle.asPredicate decl) $
        field @"typeParams" typeParams $
        field @"isTransparent" transparency
      end)
  ]

angleTypeConstDefinition
  :: Angle Hack.TypeConstDeclaration -> Angle Hack.TypeConstKind
angleTypeConstDefinition decl = var $ \typeConstKind ->
  typeConstKind `where_` [
    wild .= predicate @Hack.TypeConstDefinition (
      rec $
        field @"declaration" (Angle.asPredicate decl) $
        field @"kind" typeConstKind
      end)
  ]

-- hack enums: need to distinguish `enum T : Z` , or `enum class T : X as Y`
angleEnumDefinition
  :: Angle Hack.EnumDeclaration -> Angle (Hack.Type, Maybe Hack.Type, Bool)
angleEnumDefinition decl = vars $ \(baseType :: Angle Hack.Type)
    (asType :: Angle (Maybe Hack.Type)) (isEnumClass :: Angle Bool) ->
  tuple (baseType, asType, isEnumClass) `where_` [
    wild .= predicate @Hack.EnumDefinition (
      rec $
        field @"declaration" (Angle.asPredicate decl) $
        field @"enumBase" (Angle.asPredicate baseType) $
        field @"enumConstraint" asType $
        field @"isEnumClass" isEnumClass
      end)
  ]

angleMethodDefinition
  :: Angle Hack.MethodDeclaration -> Angle Hack.MethodDefinition
angleMethodDefinition decl = predicate @Hack.MethodDefinition $
  rec $
    field @"declaration" (Angle.asPredicate decl)
  end

angleFunctionDefinition
  :: Angle Hack.FunctionDeclaration -> Angle Hack.FunctionDefinition
angleFunctionDefinition decl = predicate @Hack.FunctionDefinition $
  rec $
    field @"declaration" (Angle.asPredicate decl)
  end

angleEntityLocation
  :: Angle Code.Entity -> Angle Code.EntityLocation
angleEntityLocation ent =
  predicate @Code.EntityLocation $
    rec $
      field @"entity" ent
    end
