#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define RD_FINAL_CLASS __attribute__((objc_subclassing_restricted))

NS_ASSUME_NONNULL_BEGIN

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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


@interface RDType : NSObject

+ (nullable instancetype)typeWithObjcTypeEncoding:(const char *)types;

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
@property (nonatomic, readonly) NSUInteger size;
@property (nonatomic, readonly, nullable) RDType *type;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDField : NSObject
@property (nonatomic, readonly) NSString *name;
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@class RDClass;
@class RDProtocol;
@class RDMethod;
@class RDProperty;
@class RDIvar;

typedef objc_property_t Property;
typedef struct objc_method_description MethodDescription;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMirror : NSObject
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDClass : RDMirror

@property (nonatomic, readonly, nullable) RDClass *super;
@property (nonatomic, readonly) RDClass *meta;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *imageName;
@property (nonatomic, readonly) int version;

@property (nonatomic, readonly) NSArray<RDProtocol *> *protocols;
@property (nonatomic, readonly) NSArray<RDProperty *> *properties;
@property (nonatomic, readonly) NSArray<RDMethod *> *methods;
@property (nonatomic, readonly) NSArray<RDIvar *> *ivars;

+ (instancetype)mirrorForObjcClass:(Class)cls;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProtocolItem : NSObject

@property (nonatomic, readonly, getter=isClassLevel) BOOL classLevel;
@property (nonatomic, readonly, getter=isRequired) BOOL required;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProtocolMethod : RDProtocolItem

@property (nonatomic, readonly) RDMethodSignature *signature;
@property (nonatomic, readonly) SEL selector;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProtocolProperty : RDProtocolItem

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) RDType *type;
@property (nonatomic, readonly) NSArray<RDPropertyAttribute *> *attributes;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProtocol : RDMirror

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray<RDProtocol *> *protocols;
@property (nonatomic, readonly) NSArray<RDProtocolProperty *> *properties;
@property (nonatomic, readonly) NSArray<RDProtocolMethod *> *methods;

+ (instancetype)mirrorForObjcProtocol:(Protocol *)protocol;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDMethod : RDMirror

@property (nonatomic, readonly) SEL selector;
@property (nonatomic, readonly, nullable) RDMethodSignature *signature;

+ (instancetype)mirrorForObjcMethod:(Method)protocol;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProperty : RDMirror

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) RDPropertySignature *signature;

+ (instancetype)mirrorForObjcProperty:(Property)property;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDIvar : RDMirror

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) ptrdiff_t offset;
@property (nonatomic, readonly) RDType *type;

+ (instancetype)mirrorForObjcIvar:(Ivar)ivar;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_END
