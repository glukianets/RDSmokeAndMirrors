#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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

typedef NS_ENUM(char, RDCompositeTypeKind) {
    RDCompositeTypeKindObject               = '@',
    RDCompositeTypeKindPointer              = '^',
    RRDCompositeTypeKindVector              = '!',
    RDCompositeTypeKindBitfield             = 'b',
    RDCompositeTypeKindComplex              = 'j',
    RDCompositeTypeKindAtomic               = 'A',
    RDCompositeTypeKindConst                = 'r',
};

typedef NS_ENUM(char, RDPrimitiveTypeKind) {
    RDPrimitiveTypeKindUnknown              = '?',
    RDPrimitiveTypeKindVoid                 = 'v',
    RDPrimitiveTypeKindClass                = '#',
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
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extern size_t const RDTypeSizeUnknown;
extern size_t const RDTypeAlignmentUnknown;

@interface RDType : NSObject

+ (nullable instancetype)typeWithObjcTypeEncoding:(const char *)types;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly) size_t size;
@property (nonatomic, readonly) size_t alignment;

- (instancetype)init NS_UNAVAILABLE;
- (NSString *_Nullable)format;
- (NSString*)description;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDUnknownType : RDType
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPrimitiveType : RDType
@property (nonatomic, readonly) RDPrimitiveTypeKind kind;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDObjectType : RDType
@property (nonatomic, readonly) NSString *className;
@property (nonatomic, readonly) NSArray<NSString *> *protocolNames;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBlockType : RDType
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDPointerType : RDType
@property (nonatomic, readonly, nullable) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDConstType : RDType
@property (nonatomic, readonly, nullable) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDAtomicType : RDType
@property (nonatomic, readonly, nullable) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDComplexType : RDType
@property (nonatomic, readonly, nullable) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDBitfieldType : RDType
@property (nonatomic, readonly) NSUInteger bitsize;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDArrayType : RDType
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly, nullable) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDField : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) size_t offset;
@property (nonatomic, readonly, nullable) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDStructType : RDType
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly, nullable) NSArray<RDField *> *fields;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDUnionType : RDType
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly, nullable) NSArray<RDField *> *fields;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMethodArgumentAttribute : NSObject
@property (nonatomic, readonly) RDMethodArgumentAttributeKind kind;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMethodArgument : NSObject
@property (nonatomic, readonly, nullable) RDType *type;
@property (nonatomic, readonly) NSUInteger offset;
@property (nonatomic, readonly) NSOrderedSet<RDMethodArgumentAttribute *> *attributes;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMethodSignature : NSObject
@property (nonatomic, readonly) NSArray<RDMethodArgument *> *arguments;
@property (nonatomic, readonly) RDMethodArgument *returnValue;

+ (nullable instancetype)signatureWithObjcTypeEncoding:(const char *)types;

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
