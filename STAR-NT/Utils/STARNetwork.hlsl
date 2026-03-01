float sigmoid(float x)
{
    return 1.0 / (1.0 + exp(-x));
}

float relu(float x)
{
    return max(0.0, x);
}

#define NEURONS0 5
#define NEURONS1 32
#define NEURONS2 16
#define NEURONS3 3

#define LAYER1 (NEURONS0 * NEURONS1)
#define LAYER2 (NEURONS1 * NEURONS2)
#define LAYER3 (NEURONS2 * NEURONS3)

float weights1[LAYER1];
float bias1[NEURONS1];
float weights2[LAYER2];
float bias2[NEURONS2];
float weights3[LAYER3];
float bias3[NEURONS3];

half3 infer(float input[NEURONS0])
{
    int i, j;
    float result[NEURONS1];
    [unroll]
    for (i = 0; i < NEURONS1; i++)
    {
        result[i] = bias1[i];
        [unroll]
        for (j = 0; j < NEURONS0; j++)
        {
            result[i] += input[j] * weights1[j * NEURONS1 + i];
        }
        result[i] = relu(result[i]);
    }   
    
    float result2[NEURONS2];
    [unroll]
    for (i = 0; i < NEURONS2; i++)
    {
        result2[i] = bias2[i];
        [unroll]
        for (j = 0; j < NEURONS1; j++) {
            result2[i] += result[j] * weights2[j * NEURONS2 + i];
        }
        result2[i] = relu(result2[i]);
    } 
    
    [unroll]
    for (i = 0; i < NEURONS3; i++)
    {
        result[i] = bias3[i];
        [unroll]
        for (j = 0; j < NEURONS2; j++)
        {
            result[i] += result2[j] * weights3[j * NEURONS3 + i];
        }
        result[i] = relu(result[i]);
    }

    return half3(result[0], result[1], result[2]);
}