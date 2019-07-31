#import "RDCommon.h"

NS_ASSUME_NONNULL_BEGIN

typedef size_t RDTypeSize;
extern RDTypeSize const RDTypeSizeUnknown;

typedef ptrdiff_t RDTypeAlign;
extern RDTypeAlign const RDTypeAlignUnknown;

typedef ptrdiff_t RDOffset;
extern RDOffset const RDOffsetUnknown;

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
    RDPropertyAttributeReadOnly             = 'R',
    RDPropertyAttributeCopy                 = 'C',
    RDPropertyAttributeRetain               = '&',
    RDPropertyAttributeNonatomic            = 'N',
    RDPropertyAttributeGetter               = 'G',
    RDPropertyAttributeSetter               = 'S',
    RDPropertyAttributeDynamic              = 'D',
    RDPropertyAttributeWeak                 = 'W',
    RDPropertyAttributeGarbageCollected     = 'P',
    RDPropertyAttributeLegacyEncoding       = 't',
    RDPropertyAttributeIvarName             = 'V',
};

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

+ (nullable instancetype)signatureWithObjcTypeEncoding:(const char *)types;
- (RDMethodArgument *)argumentAtIndex:(NSUInteger)index;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPropertyAttribute : NSObject
@property (nonatomic, readonly) RDPropertyAttributeKind kind;
@property (nonatomic, readonly, nullable) NSString *value;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPropertySignature : NSObject
@property (nonatomic, readonly, nullable) NSString *ivarName;
@property (nonatomic, readonly, nullable) RDType *type;
@property (nonatomic, readonly) NSArray<RDPropertyAttribute *> *attributes;

+ (nullable instancetype)signatureWithObjcTypeEncoding:(const char *)encoding;

@end

NS_ASSUME_NONNULL_END
