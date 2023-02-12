/////////////////////////////////////////////
//                                         //
//    Copyright (C) 2022-2022 Julian Uy    //
//  https://sites.google.com/site/awertyb  //
//                                         //
//   See details of license at "LICENSE"   //
//                                         //
/////////////////////////////////////////////

#include "extractor.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>

#include "jxl/codestream_header.h"
#include "jxl/decode.h"
#include "jxl/resizable_parallel_runner.h"
#include "jxl/types.h"

const char *plugin_info[4] = {
    "00IN",
    "JPEG XL Plugin for Susie Image Viewer",
    "*.jxl",
    "JPEG XL file (*.jxl)",
};

#if 1
#define DBGFPRINTF(...)
#else
#define DBGFPRINTF fprintf
#endif

const int header_size = 12;

int getBMPFromJXL(const uint8_t *input_data, size_t file_size,
                  BITMAPFILEHEADER *bitmap_file_header,
                  BITMAPINFOHEADER *bitmap_info_header, uint8_t **data) {
	int width, height;
	int bit_width;
	int bit_length;
	int ret;
	uint8_t *bitmap_data;
	JxlParallelRunner * runner;
	JxlDecoder * dec;
	bit_width = 0;
	bit_length = 0;
	ret = 1;
	bitmap_data = NULL;
	dec = NULL;

	runner = JxlResizableParallelRunnerCreate(NULL);
	if (NULL == runner)
	{
		DBGFPRINTF(stderr, "JxlResizableParallelRunnerCreate failed\n");
		ret = 0;
		goto cleanup;
	}

	dec = JxlDecoderCreate(NULL);
	if (NULL == dec)
	{
		DBGFPRINTF(stderr, "JxlDecoderCreate failed\n");
		ret = 0;
		goto cleanup;
	}

	if (JXL_DEC_SUCCESS != JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE))
	{
		DBGFPRINTF(stderr, "JxlDecoderSubscribeEvents failed\n");
		ret = 0;
		goto cleanup;
	}

	if (JXL_DEC_SUCCESS != JxlDecoderSetParallelRunner(dec, JxlResizableParallelRunner, runner))
	{
		DBGFPRINTF(stderr, "JxlDecoderSetParallelRunner failed\n");
		ret = 0;
		goto cleanup;
	}

	JxlBasicInfo info;
	JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_LITTLE_ENDIAN, 0};

	JxlDecoderSetInput(dec, input_data, file_size);
	JxlDecoderCloseInput(dec);

	for (;;)
	{
		JxlDecoderStatus status = JxlDecoderProcessInput(dec);

		if (status == JXL_DEC_ERROR)
		{
			DBGFPRINTF(stderr, "Decoder error\n");
			ret = 0;
			goto cleanup;
		}
		else if (status == JXL_DEC_NEED_MORE_INPUT)
		{
			DBGFPRINTF(stderr, "Error, already provided all input\n");
			ret = 0;
			goto cleanup;
		}
		else if (status == JXL_DEC_BASIC_INFO)
		{
			if (JXL_DEC_SUCCESS != JxlDecoderGetBasicInfo(dec, &info))
			{
				DBGFPRINTF(stderr, "JxlDecoderGetBasicInfo failed\n");
				ret = 0;
				goto cleanup;
			}
			width = info.xsize;
			height = info.ysize;
			bit_width = width * 4;
			bit_length = bit_width;
			JxlResizableParallelRunnerSetThreads(runner, JxlResizableParallelRunnerSuggestThreads(info.xsize, info.ysize));
		}
		else if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER)
		{
			size_t buffer_size;
			if (JXL_DEC_SUCCESS != JxlDecoderImageOutBufferSize(dec, &format, &buffer_size))
			{
				DBGFPRINTF(stderr, "JxlDecoderImageOutBufferSize failed\n");
				ret = 0;
				goto cleanup;
			}
			if (buffer_size != width * height * 4)
			{
				DBGFPRINTF(stderr, "Invalid out buffer size %" PRIu64 " %" PRIu64 "\n",
								(uint64_t)(buffer_size),
								(uint64_t)(width * height * 4));
				ret = 0;
				goto cleanup;
			}
			bitmap_data = malloc(buffer_size);
			if (NULL == bitmap_data)
			{
				ret = 0;
				goto cleanup;
			}
			if (JXL_DEC_SUCCESS != JxlDecoderSetImageOutBuffer(dec, &format, bitmap_data, buffer_size))
			{
				DBGFPRINTF(stderr, "JxlDecoderSetImageOutBuffer failed\n");
				ret = 0;
				goto cleanup;
			}
		}
		else if (status == JXL_DEC_FULL_IMAGE)
		{
			// We just need the first frame
			break;
		}
		else if (status == JXL_DEC_SUCCESS)
		{
			// All decoding successfully finished.
			break;
		}
		else
		{
			DBGFPRINTF(stderr, "Unknown decoder status\n");
			ret = 0;
			goto cleanup;
		}
	}

	// Convert from RGBA to BGRA
	// Flip along the horizontal axis
	int j;
	for (j = 0; j < height / 2; j++)
	{
		DWORD* cur_1 = (DWORD*)bitmap_data + j * width;
		DWORD* cur_2 = (DWORD*)bitmap_data + (height - (1 + j)) * width;
		for (int i = 0; i < width; i++)
		{
			DWORD tmp =
				((cur_1[i] << 16) & 0x00ff0000) |
				((cur_1[i] >> 16) & 0x000000ff) |
				((cur_1[i])       & 0xff00ff00);
			cur_1[i] =
				((cur_2[i] << 16) & 0x00ff0000) |
				((cur_2[i] >> 16) & 0x000000ff) |
				((cur_2[i])       & 0xff00ff00);
			cur_2[i] = tmp;
		}
	}
	if (height % 2)
	{
		DWORD* cur = (DWORD*)bitmap_data + j * width;
		for (int i = 0; i < width; i++)
		{
			cur[i] =
				((cur[i] << 16) & 0x00ff0000) |
				((cur[i] >> 16) & 0x000000ff) |
				((cur[i])       & 0xff00ff00);
		}
	}

	// Fill in the bitmap information and file header.
	memset(bitmap_file_header, 0, sizeof(BITMAPFILEHEADER));
	memset(bitmap_info_header, 0, sizeof(BITMAPINFOHEADER));

	bitmap_file_header->bfType = 'M' * 256 + 'B';
	bitmap_file_header->bfSize = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER) + sizeof(uint8_t) * bit_length * height;
	bitmap_file_header->bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
	bitmap_file_header->bfReserved1 = 0;
	bitmap_file_header->bfReserved2 = 0;

	bitmap_info_header->biSize = 40;
	bitmap_info_header->biWidth = width;
	bitmap_info_header->biHeight = height;
	bitmap_info_header->biPlanes = 1;
	bitmap_info_header->biBitCount = 32;
	bitmap_info_header->biCompression = 0;
	bitmap_info_header->biSizeImage = bitmap_file_header->bfSize;
	bitmap_info_header->biXPelsPerMeter = bitmap_info_header->biYPelsPerMeter = 0;
	bitmap_info_header->biClrUsed = 0;
	bitmap_info_header->biClrImportant = 0;
cleanup:
	if (NULL != bitmap_data && 0 == ret)
	{
		free(bitmap_data);
	}
	else
	{
		*data = bitmap_data;
	}
	if (NULL != runner)
	{
		JxlResizableParallelRunnerDestroy(runner);
	}
	if (NULL != dec)
	{
		JxlDecoderDestroy(dec);
	}

	return ret;
}

BOOL IsSupportedEx(const char *data) {
	JxlSignature signature = JxlSignatureCheck((const uint8_t*)data, header_size);
	BOOL res = signature != JXL_SIG_NOT_ENOUGH_BYTES && signature != JXL_SIG_INVALID;
	DBGFPRINTF(stderr, "res isSupported %i\n", res);
	return res;
}

int GetPictureInfoEx(size_t data_size, const char *data,
                     SusiePictureInfo *picture_info) {
	int width, height;
	int ret;
	JxlDecoder * dec;
	ret = SPI_ALL_RIGHT;

	dec = JxlDecoderCreate(NULL);
	if (NULL == dec)
	{
		DBGFPRINTF(stderr, "JxlDecoderCreate failed\n");
		ret = SPI_MEMORY_ERROR;
		goto cleanup;
	}

	if (JXL_DEC_SUCCESS != JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO))
	{
		DBGFPRINTF(stderr, "JxlDecoderSubscribeEvents failed\n");
		ret = SPI_MEMORY_ERROR;
		goto cleanup;
	}

	JxlBasicInfo info;

	JxlDecoderSetInput(dec, (const uint8_t*)data, data_size);
	JxlDecoderCloseInput(dec);

	for (;;)
	{
		JxlDecoderStatus status = JxlDecoderProcessInput(dec);

		if (status == JXL_DEC_ERROR)
		{
			DBGFPRINTF(stderr, "Decoder error\n");
			ret = SPI_MEMORY_ERROR;
			goto cleanup;
		}
		else if (status == JXL_DEC_NEED_MORE_INPUT)
		{
			DBGFPRINTF(stderr, "Error, already provided all input\n");
			ret = SPI_MEMORY_ERROR;
			goto cleanup;
		}
		else if (status == JXL_DEC_BASIC_INFO)
		{
			if (JXL_DEC_SUCCESS != JxlDecoderGetBasicInfo(dec, &info))
			{
				DBGFPRINTF(stderr, "JxlDecoderGetBasicInfo failed\n");
				ret = SPI_MEMORY_ERROR;
				goto cleanup;
			}
			width = info.xsize;
			height = info.ysize;
			// We just need information, break here.
			break;
		}
		else if (status == JXL_DEC_SUCCESS)
		{
			// All decoding successfully finished.
			break;
		}
		else
		{
			DBGFPRINTF(stderr, "Unknown decoder status\n");
			ret = SPI_MEMORY_ERROR;
			goto cleanup;
		}
	}

	picture_info->left = 0;
	picture_info->top = 0;
	picture_info->width = width;
	picture_info->height = height;
	picture_info->x_density = 0;
	picture_info->y_density = 0;
	picture_info->colorDepth = 32;
	picture_info->hInfo = NULL;
cleanup:
	if (NULL != dec)
	{
		JxlDecoderDestroy(dec);
	}

	return ret;
}

int GetPictureEx(size_t data_size, HANDLE *bitmap_info, HANDLE *bitmap_data,
                 SPI_PROGRESS progress_callback, intptr_t user_data, const char *data) {
	uint8_t *data_u8;
	BITMAPINFOHEADER bitmap_info_header;
	BITMAPFILEHEADER bitmap_file_header;
	BITMAPINFO *bitmap_info_locked;
	unsigned char *bitmap_data_locked;

	data_u8 = NULL;

	if (progress_callback != NULL)
		if (progress_callback(1, 1, user_data))
			return SPI_ABORT;

	if (!getBMPFromJXL((const uint8_t *)data, data_size, &bitmap_file_header,
	                   &bitmap_info_header, &data_u8))
		return SPI_MEMORY_ERROR;
	*bitmap_info = LocalAlloc(LMEM_MOVEABLE, sizeof(BITMAPINFOHEADER));
	*bitmap_data = LocalAlloc(LMEM_MOVEABLE, bitmap_file_header.bfSize -
	                                             bitmap_file_header.bfOffBits);
	if (*bitmap_info == NULL || *bitmap_data == NULL) {
		if (*bitmap_info != NULL)
			LocalFree(*bitmap_info);
		if (*bitmap_data != NULL)
			LocalFree(*bitmap_data);
		return SPI_NO_MEMORY;
	}
	bitmap_info_locked = (BITMAPINFO *)LocalLock(*bitmap_info);
	bitmap_data_locked = (unsigned char *)LocalLock(*bitmap_data);
	if (bitmap_info_locked == NULL || bitmap_data_locked == NULL) {
		LocalFree(*bitmap_info);
		LocalFree(*bitmap_data);
		return SPI_MEMORY_ERROR;
	}
	bitmap_info_locked->bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
	bitmap_info_locked->bmiHeader.biWidth = bitmap_info_header.biWidth;
	bitmap_info_locked->bmiHeader.biHeight = bitmap_info_header.biHeight;
	bitmap_info_locked->bmiHeader.biPlanes = 1;
	bitmap_info_locked->bmiHeader.biBitCount = 32;
	bitmap_info_locked->bmiHeader.biCompression = BI_RGB;
	bitmap_info_locked->bmiHeader.biSizeImage = 0;
	bitmap_info_locked->bmiHeader.biXPelsPerMeter = 0;
	bitmap_info_locked->bmiHeader.biYPelsPerMeter = 0;
	bitmap_info_locked->bmiHeader.biClrUsed = 0;
	bitmap_info_locked->bmiHeader.biClrImportant = 0;
	memcpy(bitmap_data_locked, data_u8,
	       bitmap_file_header.bfSize - bitmap_file_header.bfOffBits);

	LocalUnlock(*bitmap_info);
	LocalUnlock(*bitmap_data);
	free(data_u8);

	if (progress_callback != NULL)
		if (progress_callback(1, 1, user_data))
			return SPI_ABORT;

	return SPI_ALL_RIGHT;
}
