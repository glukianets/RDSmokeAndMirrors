#import "RDPrivate.h"

RDBlockInfo *RDBlockInfoOfBlock(id block) {
    return(__bridge RDBlockInfo *)block;
}

const char *RDBlockInfoGetObjCSignature(const RDBlockInfo *blockInfo) {
    const char *signature = NULL;

    if (blockInfo->flags & RDBlockInfoFlagHasSignature) {
        char *signaturePtr = (char *)blockInfo->descriptor;
        signaturePtr += sizeof(blockInfo->descriptor->reserved);
        signaturePtr += sizeof(blockInfo->descriptor->size);
        
        if (blockInfo->flags & RDBlockInfoFlagHasCopyDispose) {
            signaturePtr += sizeof(blockInfo->descriptor->copyHelper);
            signaturePtr += sizeof(blockInfo->descriptor->disposeHelper);
        }
        
        signature = *(const char **)signaturePtr;
    }
    return signature;
}

RDBlockKind RDBlockInfoGetKind(const RDBlockInfo *blockInfo) {
    if (blockInfo->flags & RDBlockInfoFlagIsGlobal || blockInfo->isa == &_NSConcreteGlobalBlock)
        return RDBlockKindGlobal;
    else if (blockInfo->isa == &_NSConcreteStackBlock)
        return RDBlockKindStack;
    else
        return RDBlockKindMalloc;
}
