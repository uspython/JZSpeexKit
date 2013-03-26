//
//  JZSpeexEncoder.m
//  JZSpeexKit
//
//  Created by JeffZhao on 3/25/13.
//  Copyright (c) 2013 JeffZhao. All rights reserved.
//

#import "JZSpeexEncoder.h"
#include "speexenc.c"

@implementation JZSpeexEncoder {
}

-(void)encodeInFilePath:(NSString *)inPutFilePath outFilePath:(NSString *)outPutfilePath
{
    //Input wav file 
    //default simple rate: 8000
    //default Channel: 1
    const char *inFile = [inPutFilePath UTF8String];
    const char *outFile = [outPutfilePath UTF8String];
    
    int nb_samples, total_samples=0, nb_encoded;

    FILE *fin, *fout;
    short input[MAX_FRAME_SIZE];
    spx_int32_t frame_size;
    int quiet=0;
    spx_int32_t vbr_enabled=0;
    spx_int32_t vbr_max=0;
    int abr_enabled=0;
    spx_int32_t vad_enabled=0;
    spx_int32_t dtx_enabled=0;
    int nbBytes;
    const SpeexMode *mode=NULL;
    int modeID = -1;
    void *st;
    SpeexBits bits;
    char cbits[MAX_FRAME_BYTES];
    int with_skeleton = 0;

    
    int print_bitrate=0;
    spx_int32_t rate=0;
    spx_int32_t size;
    int chan=1;
    int fmt=16;
    spx_int32_t quality=-1;
    float vbr_quality=-1;
    int lsb=1;
    ogg_stream_state os;
    ogg_stream_state so; /* ogg stream for skeleton bitstream */
    ogg_page 		 og;
    ogg_packet 		 op;
    int bytes_written=0, ret, result;
    int id=-1;
    SpeexHeader header;
    int nframes=1;
    spx_int32_t complexity=3;
    const char* speex_version;
    char vendor_string[64];
    
    int close_in=0, close_out=0;
    int eos=0;
    spx_int32_t bitrate=0;
    double cumul_bits=0, enc_frames=0;
    char first_bytes[12];
    int wave_input=0;
    spx_int32_t tmp;
    SpeexPreprocessState *preprocess = NULL;
    int denoise_enabled=0, agc_enabled=0;
    spx_int32_t lookahead = 0;
    
    speex_lib_ctl(SPEEX_LIB_GET_VERSION_STRING, (void*)&speex_version);
    snprintf(vendor_string, sizeof(vendor_string), "Encoded with Speex %s", speex_version);
    
    /*Initialize Ogg stream struct*/
    srand(time(NULL));
    if (ogg_stream_init(&os, rand())==-1)
    {
        fprintf(stderr,"Error: stream init failed\n");
        exit(1);
    }
    if (with_skeleton && ogg_stream_init(&so, rand())==-1)
    {
        fprintf(stderr,"Error: stream init failed\n");
        exit(1);
    }
    
    if (strcmp(inFile, "-")==0)
    {
#if defined WIN32 || defined _WIN32
        _setmode(_fileno(stdin), _O_BINARY);
#elif defined OS2
        _fsetmode(stdin,"b");
#endif
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
    
    {
        fread(first_bytes, 1, 12, fin);
        if (strncmp(first_bytes,"RIFF",4)==0 && strncmp(first_bytes,"RIFF",4)==0)
        {
            if (read_wav_header(fin, &rate, &chan, &fmt, &size)==-1)
                exit(1);
            wave_input=1;
            lsb=1; /* CHECK: exists big-endian .wav ?? */
        }
    }
    
    if (modeID==-1 && !rate)
    {
        /* By default, use narrowband/8 kHz */
        modeID = SPEEX_MODEID_NB;
        rate=8000;
    } else if (modeID!=-1 && rate)
    {
        mode = speex_lib_get_mode (modeID);
        if (rate>48000)
        {
            fprintf (stderr, "Error: sampling rate too high: %d Hz, try down-sampling\n", rate);
            exit(1);
        } else if (rate>25000)
        {
            if (modeID != SPEEX_MODEID_UWB)
            {
                fprintf (stderr, "Warning: Trying to encode in %s at %d Hz. I'll do it but I suggest you try ultra-wideband instead\n", mode->modeName , rate);
            }
        } else if (rate>12500)
        {
            if (modeID != SPEEX_MODEID_WB)
            {
                fprintf (stderr, "Warning: Trying to encode in %s at %d Hz. I'll do it but I suggest you try wideband instead\n", mode->modeName , rate);
            }
        } else if (rate>=6000)
        {
            if (modeID != SPEEX_MODEID_NB)
            {
                fprintf (stderr, "Warning: Trying to encode in %s at %d Hz. I'll do it but I suggest you try narrowband instead\n", mode->modeName , rate);
            }
        } else {
            fprintf (stderr, "Error: sampling rate too low: %d Hz\n", rate);
            exit(1);
        }
    } else if (modeID==-1)
    {
        if (rate>48000)
        {
            fprintf (stderr, "Error: sampling rate too high: %d Hz, try down-sampling\n", rate);
            exit(1);
        } else if (rate>25000)
        {
            modeID = SPEEX_MODEID_UWB;
        } else if (rate>12500)
        {
            modeID = SPEEX_MODEID_WB;
        } else if (rate>=6000)
        {
            modeID = SPEEX_MODEID_NB;
        } else {
            fprintf (stderr, "Error: Sampling rate too low: %d Hz\n", rate);
            exit(1);
        }
    } else if (!rate)
    {
        if (modeID == SPEEX_MODEID_NB)
            rate=8000;
        else if (modeID == SPEEX_MODEID_WB)
            rate=16000;
        else if (modeID == SPEEX_MODEID_UWB)
            rate=32000;
    }
    
    if (!quiet)
        if (rate!=8000 && rate!=16000 && rate!=32000)
            fprintf (stderr, "Warning: Speex is only optimized for 8, 16 and 32 kHz. It will still work at %d Hz but your mileage may vary\n", rate);
    
    if (!mode)
        mode = speex_lib_get_mode (modeID);
    
    speex_init_header(&header, rate, 1, mode);
    header.frames_per_packet=nframes;
    header.vbr=vbr_enabled;
    header.nb_channels = chan;
    
    {
        char *st_string="mono";
        if (chan==2)
            st_string="stereo";
        if (!quiet)
            fprintf (stderr, "Encoding %d Hz audio using %s mode (%s)\n",
                     header.rate, mode->modeName, st_string);
    }
    /*fprintf (stderr, "Encoding %d Hz audio at %d bps using %s mode\n",
     header.rate, mode->bitrate, mode->modeName);*/
    
    /*Initialize Speex encoder*/
    st = speex_encoder_init(mode);
    
    if (strcmp(outFile,"-")==0)
    {
#if defined WIN32 || defined _WIN32
        _setmode(_fileno(stdout), _O_BINARY);
#endif
        fout=stdout;
    }
    else
    {
        fout = fopen(outFile, "wb");
        if (!fout)
        {
            perror(outFile);
            exit(1);
        }
        close_out=1;
    }
    
    speex_encoder_ctl(st, SPEEX_GET_FRAME_SIZE, &frame_size);
    speex_encoder_ctl(st, SPEEX_SET_COMPLEXITY, &complexity);
    speex_encoder_ctl(st, SPEEX_SET_SAMPLING_RATE, &rate);
    
    if (quality >= 0)
    {
        if (vbr_enabled)
        {
            if (vbr_max>0)
                speex_encoder_ctl(st, SPEEX_SET_VBR_MAX_BITRATE, &vbr_max);
            speex_encoder_ctl(st, SPEEX_SET_VBR_QUALITY, &vbr_quality);
        }
        else
            speex_encoder_ctl(st, SPEEX_SET_QUALITY, &quality);
    }
    if (bitrate)
    {
        if (quality >= 0 && vbr_enabled)
            fprintf (stderr, "Warning: --bitrate option is overriding --quality\n");
        speex_encoder_ctl(st, SPEEX_SET_BITRATE, &bitrate);
    }
    if (vbr_enabled)
    {
        tmp=1;
        speex_encoder_ctl(st, SPEEX_SET_VBR, &tmp);
    } else if (vad_enabled)
    {
        tmp=1;
        speex_encoder_ctl(st, SPEEX_SET_VAD, &tmp);
    }
    if (dtx_enabled)
        speex_encoder_ctl(st, SPEEX_SET_DTX, &tmp);
    if (dtx_enabled && !(vbr_enabled || abr_enabled || vad_enabled))
    {
        fprintf (stderr, "Warning: --dtx is useless without --vad, --vbr or --abr\n");
    } else if ((vbr_enabled || abr_enabled) && (vad_enabled))
    {
        fprintf (stderr, "Warning: --vad is already implied by --vbr or --abr\n");
    }
    if (with_skeleton) {
        fprintf (stderr, "Warning: Enabling skeleton output may cause some decoders to fail.\n");
    }
    
    if (abr_enabled)
    {
        speex_encoder_ctl(st, SPEEX_SET_ABR, &abr_enabled);
    }
    
    speex_encoder_ctl(st, SPEEX_GET_LOOKAHEAD, &lookahead);
    
    if (denoise_enabled || agc_enabled)
    {
        preprocess = speex_preprocess_state_init(frame_size, rate);
        speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_DENOISE, &denoise_enabled);
        speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_AGC, &agc_enabled);
        lookahead += frame_size;
    }
    
    /* first packet should be the skeleton header. */
    
    if (with_skeleton) {
        add_fishead_packet(&so);
        if ((ret = flush_ogg_stream_to_file(&so, fout))) {
            fprintf (stderr,"Error: failed skeleton (fishead) header to output stream\n");
            exit(1);
        } else
            bytes_written += ret;
    }
    
    /*Write header*/
    {
        int packet_size;
        op.packet = (unsigned char *)speex_header_to_packet(&header, &packet_size);
        op.bytes = packet_size;
        op.b_o_s = 1;
        op.e_o_s = 0;
        op.granulepos = 0;
        op.packetno = 0;
        ogg_stream_packetin(&os, &op);
        free(op.packet);
        
        while((result = ogg_stream_flush(&os, &og)))
        {
            if(!result) break;
            ret = oe_write_page(&og, fout);
            if(ret != og.header_len + og.body_len)
            {
                fprintf (stderr,"Error: failed writing header to output stream\n");
                exit(1);
            }
            else
                bytes_written += ret;
        }
     /*Ignore comments will be ok*/
//        op.packet = (unsigned char *)comments;
//        op.bytes = comments_length;
//        op.b_o_s = 0;
//        op.e_o_s = 0;
//        op.granulepos = 0;
//        op.packetno = 1;
//        ogg_stream_packetin(&os, &op);
    }
    
    /* fisbone packet should be write after all bos pages */
    if (with_skeleton) {
        add_fisbone_packet(&so, os.serialno, &header);
        if ((ret = flush_ogg_stream_to_file(&so, fout))) {
            fprintf (stderr,"Error: failed writing skeleton (fisbone )header to output stream\n");
            exit(1);
        } else
            bytes_written += ret;
    }
    
    /* writing the rest of the speex header packets */
    while((result = ogg_stream_flush(&os, &og)))
    {
        if(!result) break;
        ret = oe_write_page(&og, fout);
        if(ret != og.header_len + og.body_len)
        {
            fprintf (stderr,"Error: failed writing header to output stream\n");
            exit(1);
        }
        else
            bytes_written += ret;
    }
    
    
    /* write the skeleton eos packet */
    if (with_skeleton) {
        add_eos_packet_to_stream(&so);
        if ((ret = flush_ogg_stream_to_file(&so, fout))) {
            fprintf (stderr,"Error: failed writing skeleton header to output stream\n");
            exit(1);
        } else
            bytes_written += ret;
    }
    
    
    speex_bits_init(&bits);
    
    if (!wave_input)
    {
        nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, first_bytes, NULL);
    } else {
        nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, NULL, &size);
    }
    if (nb_samples==0)
        eos=1;
    total_samples += nb_samples;
    nb_encoded = -lookahead;
    /*Main encoding loop (one frame per iteration)*/
    while (!eos || total_samples>nb_encoded)
    {
        id++;
        /*Encode current frame*/
        if (chan==2)
            speex_encode_stereo_int(input, frame_size, &bits);
        
        if (preprocess)
            speex_preprocess(preprocess, input, NULL);
        
        speex_encode_int(st, input, &bits);
        
        nb_encoded += frame_size;
        if (print_bitrate) {
            int tmp;
            char ch=13;
            speex_encoder_ctl(st, SPEEX_GET_BITRATE, &tmp);
            fputc (ch, stderr);
            cumul_bits += tmp;
            enc_frames += 1;
            if (!quiet)
            {
                if (vad_enabled || vbr_enabled || abr_enabled)
                    fprintf (stderr, "Bitrate is use: %d bps  (average %d bps)   ", tmp, (int)(cumul_bits/enc_frames));
                else
                    fprintf (stderr, "Bitrate is use: %d bps     ", tmp);
            }
            
        }
        
        if (wave_input)
        {
            nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, NULL, &size);
        } else {
            nb_samples = read_samples(fin,frame_size,fmt,chan,lsb,input, NULL, NULL);
        }
        if (nb_samples==0)
        {
            eos=1;
        }
        if (eos && total_samples<=nb_encoded)
            op.e_o_s = 1;
        else
            op.e_o_s = 0;
        total_samples += nb_samples;
        
        if ((id+1)%nframes!=0)
            continue;
        speex_bits_insert_terminator(&bits);
        nbBytes = speex_bits_write(&bits, cbits, MAX_FRAME_BYTES);
        speex_bits_reset(&bits);
        op.packet = (unsigned char *)cbits;
        op.bytes = nbBytes;
        op.b_o_s = 0;
        /*Is this redundent?*/
        if (eos && total_samples<=nb_encoded)
            op.e_o_s = 1;
        else
            op.e_o_s = 0;
        op.granulepos = (id+1)*frame_size-lookahead;
        if (op.granulepos>total_samples)
            op.granulepos = total_samples;
        /*printf ("granulepos: %d %d %d %d %d %d\n", (int)op.granulepos, id, nframes, lookahead, 5, 6);*/
        op.packetno = 2+id/nframes;
        ogg_stream_packetin(&os, &op);
        
        /*Write all new pages (most likely 0 or 1)*/
        while (ogg_stream_pageout(&os,&og))
        {
            ret = oe_write_page(&og, fout);
            if(ret != og.header_len + og.body_len)
            {
                fprintf (stderr,"Error: failed writing header to output stream\n");
                exit(1);
            }
            else
                bytes_written += ret;
        }
    }
    if ((id+1)%nframes!=0)
    {
        while ((id+1)%nframes!=0)
        {
            id++;
            speex_bits_pack(&bits, 15, 5);
        }
        nbBytes = speex_bits_write(&bits, cbits, MAX_FRAME_BYTES);
        op.packet = (unsigned char *)cbits;
        op.bytes = nbBytes;
        op.b_o_s = 0;
        op.e_o_s = 1;
        op.granulepos = (id+1)*frame_size-lookahead;
        if (op.granulepos>total_samples)
            op.granulepos = total_samples;
        
        op.packetno = 2+id/nframes;
        ogg_stream_packetin(&os, &op);
    }
    /*Flush all pages left to be written*/
    while (ogg_stream_flush(&os, &og))
    {
        ret = oe_write_page(&og, fout);
        if(ret != og.header_len + og.body_len)
        {
            fprintf (stderr,"Error: failed writing header to output stream\n");
            exit(1);
        }
        else
            bytes_written += ret;
    }
    
    speex_encoder_destroy(st);
    speex_bits_destroy(&bits);
    ogg_stream_clear(&os);
    
    if (close_in)
        fclose(fin);
    if (close_out)
        fclose(fout);
    
}

@end
