#include <stdio.h>

__global__ void nearToeplitzCyclicReductionKernel( double *a_d,
                                double *b_d,
                                double *c_d,
                                double *d_d,
                                double *k1_d,
                                double *k2_d,
                                double *b_first_d,
                                double *k1_first_d,
                                double *k1_last_d,
                                const double b1,
                                const double c1,
                                const double ai,
                                const double bi,
                                const double ci)
                                {
    /*

    */
    __shared__ double d_l[{{shared_size | int}}];

    int tix = threadIdx.x; 
    int offset = blockIdx.x*{{n}};
    int i, j, k;
    int idx;
    double d_j, d_k;

    /* When loading to shared memory, perform the first
       reduction step */
    idx = 0;
    if (tix == 0) {
        d_l[tix] = d_d[offset+2*tix+1] - \
                    d_d[offset+2*tix]*k1_first_d[idx] - \
                    d_d[offset+2*tix+2]*k2_d[idx];
    }
    else if (tix == ({{(n/2) | int}}-1)) {
        d_l[tix] = d_d[offset+2*tix+1] - \
                    d_d[offset+2*tix]*k1_last_d[idx];
    }
    else {
        d_l[tix] = d_d[offset+2*tix+1] - \
                    d_d[offset+2*tix]*k1_d[idx] - \
                    d_d[offset+2*tix+2]*k2_d[idx];
    }
    __syncthreads();
    
    /* First step of reduction is complete and 
       the coefficients are in shared memory */
    
    /* Do the remaining forward reduction steps: */
    for (int stride=2; stride<{{(n/2) | int}}; stride=stride*2) {
        idx = idx + 1;
        i = (stride-1) + tix*stride;
        if (tix < {{n}}/(2*stride)) {
            if (tix == 0) {
                d_l[i] = d_l[i] - \
                            d_l[i-stride/2]*k1_first_d[idx] - \
                            d_l[i+stride/2]*k2_d[idx];
            }
            else if (i == ({{n}}/2-1)) {
                d_l[i] = d_l[i] - \
                             d_l[i-stride/2]*k1_last_d[idx];
            }
            else {
                d_l[i] = d_l[i] - d_l[i-stride/2]*k1_d[idx] - \
                            d_l[i+stride/2]*k2_d[idx];
            }
        }
        __syncthreads();
    }

    if (tix == 0) {
        j = rint(log2((float) {{(n/2) | int}})) - 1;
        k = rint(log2((float) {{(n/2) | int}}));

        d_j = (d_l[{{n}}/4-1]*b_d[k] - \
               c_d[j]*d_l[{{n}}/2-1])/ \
            (b_first_d[j]*b_d[k] - c_d[j]*a_d[k]);

        d_k = (b_first_d[j]*d_l[{{n}}/2-1] - \
               d_l[{{n}}/4-1]*a_d[k])/ \
            (b_first_d[j]*b_d[k] - c_d[j]*a_d[k]);

        d_l[{{n}}/4-1] = d_j;
        d_l[{{n}}/2-1] = d_k;
    }
    __syncthreads();
    
    idx = rint(log2((float) {{n}}))-2;
    for (int stride={{n}}/4; stride>1; stride=stride/2) {
        idx = idx - 1;
        i = (stride/2-1) + tix*stride;
        if (tix < {{n}}/(2*stride)){
            if (tix == 0) {
                d_l[i] = (d_l[i] - c_d[idx]*d_l[i+stride/2])/\
                            b_first_d[idx];
            }
            else {
                d_l[i] = (d_l[i] - a_d[idx]*d_l[i-stride/2] -\
                            c_d[idx]*d_l[i+stride/2])/b_d[idx];
            }
        }
        __syncthreads();
    }

    //When writing from shared memory, perform the last
    //substitution step
    if (tix == 0) {
        d_d[offset+2*tix] = (d_d[offset+2*tix] - c1*d_l[tix])/b1;
        d_d[offset+2*tix+1] = d_l[tix];
    }
    else {
        d_d[offset+2*tix] = (d_d[offset+2*tix] - \
                                ai*d_l[tix-1] - ci*d_l[tix])/bi;
        d_d[offset+2*tix+1] = d_l[tix];
    } 
    
    __syncthreads();
}

