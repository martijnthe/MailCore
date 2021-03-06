/*
 * MailCore
 *
 * Copyright (C) 2007 - Matt Ronge
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the MailCore project nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#import "CTMIME_TextPart.h"

#import <libetpan/libetpan.h>
#import "MailCoreTypes.h"

@implementation CTMIME_TextPart
+ (id)mimeTextPartWithString:(NSString *)str {
	return [[[CTMIME_TextPart alloc] initWithString:str] autorelease];
}

- (id)initWithString:(NSString *)string {
	self = [super init];
	if (self) {
		[self setString:string];
        [self setContentType:@"text/plain"];
	}
	return self;
}

- (id)content {
	if (mMimeFields != NULL) {
		// We are decoding from an existing msg so read
		// the charset and convert from that to UTF-8
		char *converted;
		size_t converted_len;
		
		char *source_charset = mMimeFields->fld_content_charset;
		if (source_charset == NULL) {
			source_charset = DEST_CHARSET;
		}
		
		int r = charconv_buffer(DEST_CHARSET, source_charset,
								self.data.bytes, self.data.length,
								&converted, &converted_len);
		NSString *str = @"";
		if (r == MAIL_CHARCONV_NO_ERROR) {
			NSData *newData = [NSData dataWithBytes:converted length:converted_len];
			str = [[[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding] autorelease];
		}
		charconv_buffer_free(converted);
		return str;
	} else {
		// Don't have a charset available so treat data as UTF-8
		// This will happen when we are creating a msg and not decoding
		// an existing one
		return [[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding] autorelease];
	}
}

- (void)setString:(NSString *)str {
	self.data = [str dataUsingEncoding:NSUTF8StringEncoding];
	// The data is all local, so we don't want it to do any fetching
	self.fetched = YES;
}

- (struct mailmime *)buildMIMEStruct {
	struct mailmime_fields *mime_fields;
	struct mailmime *mime_sub;
	struct mailmime_content *content;
	struct mailmime_parameter *param;
	int r;

	/* text/plain part */
	//TODO this needs to be changed, something other than 8BIT should be used
	mime_fields = mailmime_fields_new_encoding(MAILMIME_MECHANISM_8BIT);
	assert(mime_fields != NULL);

	content = mailmime_content_new_with_str([self.contentType cStringUsingEncoding:NSUTF8StringEncoding]);
	assert(content != NULL);

	param = mailmime_parameter_new(strdup("charset"), strdup(DEST_CHARSET));
	assert(param != NULL);
	
	r = clist_append(content->ct_parameters, param);
	assert(r >= 0);

	mime_sub = mailmime_new_empty(content, mime_fields);
	assert(mime_sub != NULL);
	NSString *str = [self content];
	//TODO is strdup necessary?
	r = mailmime_set_body_text(mime_sub, strdup([str cStringUsingEncoding:NSUTF8StringEncoding]), [str length]);
	assert(r == MAILIMF_NO_ERROR);
	return mime_sub;
}
@end
