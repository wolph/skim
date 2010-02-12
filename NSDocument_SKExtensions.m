//
//  NSDocument_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 5/23/08.
/*
 This software is Copyright (c) 2008-2010
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSDocument_SKExtensions.h"
#import "SKApplicationController.h"
#import "SKTemplateParser.h"
#import "NSFileManager_SKExtensions.h"
#import "SKDocumentController.h"
#import "BDAlias.h"

NSString *SKDocumentErrorDomain = @"SKDocumentErrorDomain";

@implementation NSDocument (SKExtensions)

static NSSet *richTextTypes() {
    static NSSet *types = nil;
    if (types == nil)
        types = [[NSSet alloc] initWithObjects:@"rtf", @"doc", @"docx", @"odt", @"rtfd", nil];
    return types;
}

- (NSString *)notesStringUsingTemplateFile:(NSString *)templateFile {
    NSString *fileType = [[templateFile pathExtension] lowercaseString];
    NSString *string = nil;
    if ([richTextTypes() containsObject:fileType] == NO) {
        NSString *templatePath = [[NSFileManager defaultManager] pathForApplicationSupportFile:[templateFile stringByDeletingPathExtension] ofType:[templateFile pathExtension] inDirectory:@"Templates"];
        NSError *error = nil;
        NSString *templateString = [[NSString alloc] initWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:&error];
        string = [SKTemplateParser stringByParsingTemplateString:templateString usingObject:self];
        [templateString release];
    }
    return string;
}

- (NSData *)notesDataUsingTemplateFile:(NSString *)templateFile {
    NSString *fileType = [[templateFile pathExtension] lowercaseString];
    NSData *data = nil;
    if ([richTextTypes() containsObject:fileType]) {
        NSString *templatePath = [[NSFileManager defaultManager] pathForApplicationSupportFile:[templateFile stringByDeletingPathExtension] ofType:[templateFile pathExtension] inDirectory:@"Templates"];
        NSDictionary *docAttributes = nil;
        NSError *error = nil;
        NSAttributedString *templateAttrString = [[NSAttributedString alloc] initWithPath:templatePath documentAttributes:&docAttributes];
        NSAttributedString *attrString = [SKTemplateParser attributedStringByParsingTemplateAttributedString:templateAttrString usingObject:self];
        data = [attrString dataFromRange:NSMakeRange(0, [attrString length]) documentAttributes:docAttributes error:&error];
        [templateAttrString release];
    } else {
        data = [[self notesStringUsingTemplateFile:templateFile] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    }
    return data;
}

- (NSFileWrapper *)notesFileWrapperUsingTemplateFile:(NSString *)templateFile {
    NSFileWrapper *fileWrapper = nil;
    if ([[templateFile pathExtension] caseInsensitiveCompare:@"rtfd"] == NSOrderedSame) {
        NSString *templatePath = [[NSFileManager defaultManager] pathForApplicationSupportFile:[templateFile stringByDeletingPathExtension] ofType:[templateFile pathExtension] inDirectory:@"Templates"];
        NSDictionary *docAttributes = nil;
        NSAttributedString *templateAttrString = [[NSAttributedString alloc] initWithPath:templatePath documentAttributes:&docAttributes];
        NSAttributedString *attrString = [SKTemplateParser attributedStringByParsingTemplateAttributedString:templateAttrString usingObject:self];
        fileWrapper = [attrString RTFDFileWrapperFromRange:NSMakeRange(0, [attrString length]) documentAttributes:docAttributes];
        [templateAttrString release];
    }
    return fileWrapper;
}

- (NSString *)notesString {
    return [self notesStringUsingTemplateFile:@"notesTemplate.txt"];
}

- (NSData *)notesRTFData {
    return [self notesDataUsingTemplateFile:@"notesTemplate.rtf"];
}

- (NSFileWrapper *)notesRTFDFileWrapper {
    return [self notesFileWrapperUsingTemplateFile:@"notesTemplate.rtfd"];
}

- (void)saveRecentDocumentInfo {}

- (void)applySetup:(NSDictionary *)setup {}

// these are necessary for the app controller, we may change it there
- (NSDictionary *)currentDocumentSetup {
    NSMutableDictionary *setup = [NSMutableDictionary dictionary];
    NSString *fileName = [[self fileURL] path];
    
    if (fileName) {
        NSData *data = [[BDAlias aliasWithPath:fileName] aliasData];
        
        [setup setObject:fileName forKey:SKDocumentSetupFileNameKey];
        if(data)
            [setup setObject:data forKey:SKDocumentSetupAliasKey];
    }
    
    return setup;
}

#pragma mark Scripting

- (NSArray *)pages { return nil; }

- (NSArray *)notes { return nil; }

- (PDFPage *)currentPage { return nil; }

- (id)activeNote { return nil; }

- (NSTextStorage *)richText { return nil; }

- (id)selectionSpecifier { return nil; }

- (NSData *)selectionQDRect { return nil; }

- (id)selectionPage { return nil; }

- (NSDictionary *)pdfViewSettings { return nil; }

- (NSDictionary *)documentAttributes { return nil; }

- (void)handleRevertScriptCommand:(NSScriptCommand *)command {
    if ([self fileURL] && [[NSFileManager defaultManager] fileExistsAtPath:[[self fileURL] path]]) {
        if ([self revertToContentsOfURL:[self fileURL] ofType:[self fileType] error:NULL] == NO) {
            [command setScriptErrorNumber:NSInternalScriptError];
            [command setScriptErrorString:@"Revert failed."];
        }
    } else {
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"File does not exist."];
    }
}

- (void)handleGoToScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'go' command."];
}

- (id)handleFindScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'find' command."];
    return nil;
}

- (void)handleShowTeXScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'show TeX file' command."];
}

- (void)handleConvertNotesScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'convert notes' command."];
}

@end