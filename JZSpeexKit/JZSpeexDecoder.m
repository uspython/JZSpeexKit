//
//  JZSpeexDecoder.m
//  JZSpeexKit
//
//  Created by JeffZhao on 3/25/13.
//  Copyright (c) 2013 JeffZhao. All rights reserved.
//

#import "JZSpeexDecoder.h"
#include "speexdec.c"

#define MAX_FRAME_SIZE 2000

@implementation JZSpeexDecoder

- (void)decodeInFilePath:(NSString *)inputFilePath outFilePath:(NSString *)outPutfilePath {
    
    //Output wav file
    //simple rate: 8000
    //Channel: 1
    const char *inFile = [inputFilePath UTF8String];
    const char *outFile = [outPutfilePath UTF8String];
    
    FILE *fin, *fout=NULL;
    short out[MAX_FRAME_SIZE];
    short output[MAX_FRAME_SIZE];
    int frame_size=0, granule_frame_size=0;
    void *st=NULL;
    SpeexBits bits;
    int packet_count=0;
    int stream_init = 0;
    int quiet = 0;
    ogg_int64_t page_granule=0, last_granule=0;
    int skip_samples=0, page_nb_packets;
    ogg_sync_state oy;
    ogg_page       og;
    ogg_packet     op;
    ogg_stream_state os;
    int enh_enabled;
    int nframes=2;
    int print_bitrate=0;
    int close_in=0;
    int eos=0;
    int forceMode=-1;
    int audio_size=0;
    float loss_percent=-1;
    SpeexStereoState stereo = SPEEX_STEREO_STATE_INIT;
    int channels=1;
    int rate=0;
    int extra_headers=0;
    int wav_format=0;
    int lookahead;
    int speex_serialno = -1;
    
    enh_enabled = 1;  
    wav_format = strlen(outFile)>=4 && (
                                        strcmp(outFile+strlen(outFile)-4,".wav")==0
                                        || strcmp(outFile+strlen(outFile)-4,".WAV")==0);
    /*Open input file*/
    if (strcmp(inFile, "-")==0)
    {
        fin=stdin;
    }
    else 
    {
        fin = fopen(inFile, "rb");
        if (!fin)
        {
            perror(inFile);
            exit(1);
        }
        close_in=1;
    }
    
    
    /*Init Ogg data struct*/
    ogg_sync_init(&oy);
    
    speex_bits_init(&bits);
    /*Main decoding loop*/
    
    while (1)
    {
        char *data;
        int i, j, nb_read;
        /*Get the ogg buffer for writing*/
        data = ogg_sync_buffer(&oy, 200);
        /*Read bitstream from input file*/
        nb_read = fread(data, sizeof(char), 200, fin);      
        ogg_sync_wrote(&oy, nb_read);
        
        /*Loop for all complete pages we got (most likely only one)*/
        while (ogg_sync_pageout(&oy, &og)==1)
        {
            int packet_no;
            if (stream_init == 0) {
                ogg_stream_init(&os, ogg_page_serialno(&og));
                stream_init = 1;
            }
            if (ogg_page_serialno(&og) != os.serialno) {
                /* so all streams are read. */
                ogg_stream_reset_serialno(&os, ogg_page_serialno(&og));
            }
            /*Add page to the bitstream*/
            ogg_stream_pagein(&os, &og);
            page_granule = ogg_page_granulepos(&og);
            page_nb_packets = ogg_page_packets(&og);
            if (page_granule>0 && frame_size)
            {
                /* FIXME: shift the granule values if --force-* is specified */
                skip_samples = frame_size*(page_nb_packets*granule_frame_size*nframes - (page_granule-last_granule))/granule_frame_size;
                if (ogg_page_eos(&og))
                    skip_samples = -skip_samples;

            } else
            {
                skip_samples = 0;
            }
            last_granule = page_granule;
            /*Extract all available packets*/
            packet_no=0;
            while (!eos && ogg_stream_packetout(&os, &op) == 1)
            {
                if (op.bytes>=5 && !memcmp(op.packet, "Speex", 5)) {
                    speex_serialno = os.serialno;
                }
                if (speex_serialno == -1 || os.serialno != speex_serialno)
                    break;
                /*If first packet, process as Speex header*/
                if (packet_count==0)
                {
                    st = process_header(&op, enh_enabled, &frame_size, &granule_frame_size, &rate, &nframes, forceMode, &channels, &stereo, &extra_headers, quiet);
                    if (!st)
                        exit(1);
                    speex_decoder_ctl(st, SPEEX_GET_LOOKAHEAD, &lookahead);
                    if (!nframes)
                        nframes=1;
                    fout = out_file_open((char *)outFile, rate, &channels);
                } else if (packet_count<=1+extra_headers)
                {
                    /* Ignore extra headers */
                } else {
                    int lost=0;
                    packet_no++;
                    if (loss_percent>0 && 100*((float)rand())/RAND_MAX<loss_percent)
                        lost=1;
                    
                    /*End of stream condition*/
                    if (op.e_o_s && os.serialno == speex_serialno) /* don't care for anything except speex eos */
                        eos=1;
                    
                    /*Copy Ogg packet to Speex bitstream*/
                    speex_bits_read_from(&bits, (char*)op.packet, op.bytes);
                    for (j=0;j!=nframes;j++)
                    {
                        int ret;
                        /*Decode frame*/
                        if (!lost)
                            ret = speex_decode_int(st, &bits, output);
                        else
                            ret = speex_decode_int(st, NULL, output);
                        
                        if (ret==-1)
                            break;
                        if (ret==-2)
                        {
                            fprintf (stderr, "Decoding error: corrupted stream?\n");
                            break;
                        }
                        if (speex_bits_remaining(&bits)<0)
                        {
                            fprintf (stderr, "Decoding overflow: corrupted stream?\n");
                            break;
                        }
                        if (channels==2)
                            speex_decode_stereo_int(output, frame_size, &stereo);
                        
                        if (print_bitrate) {
                            spx_int32_t tmp;
                            char ch=13;
                            speex_decoder_ctl(st, SPEEX_GET_BITRATE, &tmp);
                            fputc (ch, stderr);
                            fprintf (stderr, "Bitrate is use: %d bps     ", tmp);
                        }
                        /*Convert to short and save to output file*/
                        if (strlen(outFile)!=0)
                        {
                            for (i=0;i<frame_size*channels;i++)
                                out[i]=le_short(output[i]);
                        } else {
                            for (i=0;i<frame_size*channels;i++)
                                out[i]=output[i];
                        }
                        {
                            int frame_offset = 0;
                            int new_frame_size = frame_size;
                            if (packet_no == 1 && j==0 && skip_samples > 0)
                            {
                                /*printf ("chopping first packet\n");*/
                                new_frame_size -= skip_samples+lookahead;
                                frame_offset = skip_samples+lookahead;
                            }
                            if (packet_no == page_nb_packets && skip_samples < 0)
                            {
                                int packet_length = nframes*frame_size+skip_samples+lookahead;
                                new_frame_size = packet_length - j*frame_size;
                                if (new_frame_size<0)
                                    new_frame_size = 0;
                                if (new_frame_size>frame_size)
                                    new_frame_size = frame_size;
                            }
                            if (new_frame_size>0)
                            {  
                                    fwrite(out+frame_offset*channels, sizeof(short), new_frame_size*channels, fout);
                                
                                audio_size+=sizeof(short)*new_frame_size*channels;
                            }
                        }
                    }
                }
                packet_count++;
            }
        }
        if (feof(fin))
            break;
        
    }
    
    if (fout && wav_format)
    {
        if (fseek(fout,4,SEEK_SET)==0)
        {
            int tmp;
            tmp = le_int(audio_size+36);
            fwrite(&tmp,4,1,fout);
            if (fseek(fout,32,SEEK_CUR)==0)
            {
                tmp = le_int(audio_size);
                fwrite(&tmp,4,1,fout);
            } else
            {
                fprintf (stderr, "First seek worked, second didn't\n");
            }
        } else {
            fprintf (stderr, "Cannot seek on wave file, size will be incorrect\n");
        }
    }
    
    if (st)
        speex_decoder_destroy(st);
    else 
    {
        fprintf (stderr, "This doesn't look like a Speex file\n");
    }
    speex_bits_destroy(&bits);
    if (stream_init)
        ogg_stream_clear(&os);
    ogg_sync_clear(&oy);
    
    if (close_in)
        fclose(fin);
    if (fout != NULL)
        fclose(fout);    
}


- (void)dealloc {
    [super dealloc];
}

@end
