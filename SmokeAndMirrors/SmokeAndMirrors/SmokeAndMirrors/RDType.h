#import "RDCommon.h"

NS_ASSUME_NONNULL_BEGIN

typedef size_t RDTypeSize;
RD_EXTERN RDTypeSize const RDTypeSizeUnknown;

typedef ptrdiff_t RDTypeAlign;
RD_EXTERN RDTypeAlign const RDTypeAlignUnknown;

typedef ptrdiff_t RDOffset;
RD_EXTERN RDOffset const RDOffsetUnknown;

typedef NS_ENUM(char, RDTypeEncodingSymbol) {
    RDTypeEncodingSymbolArrayBegin          = '[',
    RDTypeEncodingSymbolArrayEnd            = ']',
    RDTypeEncodingSymbolUnionBegin          = '(',
    RDTypeEncodingSymbolUnionEnd            = ')',
    RDTypeEncodingSymbolStructBegin         = '{',
    RDTypeEncodingSymbolStructEnd           = '}',
    RDTypeEncodingSymbolBlockArgsBegin      = '<',
    RDTypeEncodingSymbolBlockArgsEnd        = '>',
    RDTypeEncodingSymbolStructBodySep       = '=',
    RDTypeEncodingSymbolQuote               = '"',
};

typedef NS_ENUM(char, RDSpecialTypeKind) {
    RDSpecialTypeKindUnknown                = '?',
    RDSpecialTypeKindVoid                   = 'v',
    RDSpecialTypeKindBitfield               = 'b',
};

typedef NS_ENUM(char, RDObjectTypeKind) {
    RDObjectTypeKindGeneric                 = '@',
    RDObjectTypeKindBlock                   = '?',
    RDObjectTypeKindClass                   = '#',
};

typedef NS_ENUM(char, RDCompositeTypeKind) {
    RDCompositeTypeKindPointer              = '^',
    RDCompositeTypeKindVector               = '!',
    RDCompositeTypeKindComplex              = 'j',
    RDCompositeTypeKindAtomic               = 'A',
    RDCompositeTypeKindConst                = 'r',
};

typedef NS_ENUM(char, RDPrimitiveTypeKind) {
    RDPrimitiveTypeKindSelector             = ':',
    RDPrimitiveTypeKindCString              = '*',
    RDPrimitiveTypeKindAtom                 = '%',
    RDPrimitiveTypeKindChar                 = 'c',
    RDPrimitiveTypeKindUnsignedChar         = 'C',
    RDPrimitiveTypeKindBool                 = 'B',
    RDPrimitiveTypeKindShort                = 's',
    RDPrimitiveTypeKindUnsignedShort        = 'S',
    RDPrimitiveTypeKindInt                  = 'i',
    RDPrimitiveTypeKindUnsignedInt          = 'I',
    RDPrimitiveTypeKindLong                 = 'l',
    RDPrimitiveTypeKindUnsignedLong         = 'L',
    RDPrimitiveTypeKindLongLong             = 'q',
    RDPrimitiveTypeKindUnsignedLongLong     = 'Q',
    RDPrimitiveTypeKindInt128               = 't',
    RDPrimitiveTypeKindUnsignedInt128       = 'T',
    RDPrimitiveTypeKindFloat                = 'f',
    RDPrimitiveTypeKindDouble               = 'd',
    RDPrimitiveTypeKindLongDouble           = 'D',
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(char, RDAggregateTypeKind) {
    RDAggregateTypeKindStruct               = '{',
    RDAggregateTypeKindUnion                = '(',
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(char, RDMethodArgumentAttributeKind) {
    RDMethodArgumentAttributeKindConst      = 'r',
    RDMethodArgumentAttributeKindIn         = 'n',
    RDMethodArgumentAttributeKindOut        = 'o',
    RDMethodArgumentAttributeKindInOut      = 'N',
    RDMethodArgumentAttributeKindByCopy     = 'O',
    RDMethodArgumentAttributeKindByRef      = 'R',
    RDMethodArgumentAttributeKindOneWay     = 'V',
    RDMethodArgumentAttributeKindWTF        = '!',
};

typedef NS_OPTIONS(NSUInteger, RDMethodArgumentAttributes) {
    RDMethodArgumentAttributeConst      = (1 << 0),
    RDMethodArgumentAttributeIn         = (1 << 1),
    RDMethodArgumentAttributeOut        = (1 << 2),
    RDMethodArgumentAttributeInOut      = (1 << 3),
    RDMethodArgumentAttributeByCopy     = (1 << 4),
    RDMethodArgumentAttributeByRef      = (1 << 5),
    RDMethodArgumentAttributeOneWay     = (1 << 6),
    RDMethodArgumentAttributeWTF        = (1 << 7),
};

static RDMethodArgumentAttributes RDMethodArgumentAttributesNone = 0;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(char, RDPropertyAttributeKind) {
    RDPropertyAttributeKindReadOnly             = 'R',
    RDPropertyAttributeKindCopy                 = 'C',
    RDPropertyAttributeKindRetain               = '&',
    RDPropertyAttributeKindNonatomic            = 'N',
    RDPropertyAttributeKindGetter               = 'G',
    RDPropertyAttributeKindSetter               = 'S',
    RDPropertyAttributeKindDynamic              = 'D',
    RDPropertyAttributeKindWeak                 = 'W',
    RDPropertyAttributeKindGarbageCollected     = 'P',
    RDPropertyAttributeKindLegacyEncoding       = 't',
    RDPropertyAttributeKindIvarName             = 'V',
};

typedef NS_OPTIONS(NSUInteger, RDPropertyAttributes) {
    RDPropertyAttributeReadOnly             = (1 << 0),
    RDPropertyAttributeCopy                 = (1 << 0),
    RDPropertyAttributeRetain               = (1 << 0),
    RDPropertyAttributeNonatomic            = (1 << 0),
    RDPropertyAttributeGetter               = (1 << 0),
    RDPropertyAttributeSetter               = (1 << 0),
    RDPropertyAttributeDynamic              = (1 << 0),
    RDPropertyAttributeWeak                 = (1 << 0),
    RDPropertyAttributeGarbageCollected     = (1 << 0),
    RDPropertyAttributeLegacyEncoding       = (1 << 0),
    RDPropertyAttributeIvarName             = (1 << 0),
};

RD_EXTERN NSArray<NSNumber *> *RDAllPropertyAttributeKinds(void);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDType : NSObject<NSSecureCoding>

@property (nonatomic, readonly) size_t size;
@property (nonatomic, readonly) size_t alignment;
@property (nonatomic, readonly) const char *objCTypeEncoding;

+ (nullable instancetype)typeWithObjcTypeEncoding:(nullable const char *)types;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;
- (NSString *_Nullable)format;
- (NSString*)description;

- (BOOL)isEqualToType:(nullable RDType *)type;
- (BOOL)isAssignableFromType:(nullable RDType *)type;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDUnknownType : RDType
@property (nonatomic, readonly, class) RDUnknownType *instance;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDVoidType : RDType
@property (nonatomic, readonly, class) RDUnknownType *instance;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDObjectType : RDType
@property (nonatomic, readonly) RDObjectTypeKind kind;
@property (nonatomic, readonly, nullable) NSString *className;
@property (nonatomic, readonly, nullable) NSArray<NSString *> *protocolNames;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPrimitiveType : RDType
@property (nonatomic, readonly) RDPrimitiveTypeKind kind;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDCompositeType : RDType
@property (nonatomic, readonly) RDCompositeTypeKind kind;
@property (nonatomic, readonly) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBitfieldType : RDType
@property (nonatomic, readonly) NSUInteger bitsize;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDArrayType : RDType
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly, nullable) RDType *type;

- (size_t)offsetForElementAtIndex:(NSUInteger)index;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef struct {
    RDType *type;
    NSString *name;
    RDOffset offset;
} RDField;

RD_FINAL_CLASS
@interface RDAggregateType : RDType
@property (nonatomic, readonly) RDAggregateTypeKind kind;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly) NSUInteger count;

- (instancetype)initWithKind:(RDAggregateTypeKind)kind name:(nullable NSString *)name, ... NS_REQUIRES_NIL_TERMINATION;

- (nullable RDField *)fieldAtIndex:(NSUInteger)index;
- (nullable RDField *)fieldAtOffset:(RDOffset)offset;
- (nullable RDField *)fieldWithName:(NSString *)name;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef struct {
    RDType *type;
    RDOffset offset;
    RDMethodArgumentAttributes attributes;
} RDMethodArgument;

RD_FINAL_CLASS
@interface RDMethodSignature : NSObject
@property (nonatomic, readonly) NSUInteger argumentsCount;
@property (nonatomic, readonly) RDMethodArgument *returnValue;
@property (nonatomic, readonly) BOOL isMethodSignature;
@property (nonatomic, readonly) BOOL isBlockSignature;

+ (nullable instancetype)signatureWithObjcTypeEncoding:(const char *)types;
- (RDMethodArgument *)argumentAtIndex:(NSUInteger)index;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef struct {
    RDPropertyAttributeKind kind;
    NSString *value;
} RDPropertyAttribute;

@interface RDPropertySignature : NSObject
@property (nonatomic, readonly, nullable) NSString *ivarName;
@property (nonatomic, readonly, nullable) RDType *type;
@property (nonatomic, readonly) NSUInteger attributesCount;

+ (nullable instancetype)signatureWithObjcTypeEncoding:(const char *)encoding;
- (RDPropertyAttribute *)attributeWithKind:(RDPropertyAttributeKind)kind;

@end

NS_ASSUME_NONNULL_END
