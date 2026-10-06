#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, set = 0, binding = 1) uniform readonly image2D input_heightmap;

layout(rgba32f, set = 0, binding = 2) uniform writeonly image2D output_heightmap;

layout(push_constant, std430) uniform Parameters {
        int width;
        float inertia;
        float sedimentCapacityFactor;
        float minSedimentCapacity;
        float erosionSpeed;
        float depositionSpeed;
        float evaporationRate;
        float gravity;
        int useErosion;
        int steps;
        float seed;
} params;

struct Droplet {
        vec2 pos;
        vec2 dir;
        float speed;
        float water;
        float sediment;
};

layout(set = 0, binding = 3, std430) buffer DropletBuffer {
        Droplet droplets[];
};

layout(set = 0, binding = 4, std430) buffer HeightBuffer {
        float heights[];
};

int get_index(int x, int y) {
        int cx = clamp(x, 0, params.width - 1);
        int cy = clamp(y, 0, params.width - 1);
        return cx + (cy * params.width);
}

float hash(uint x) {
        x = ((x >> 16) ^ x) * 0x45d9f3bu;
        x = ((x >> 16) ^ x) * 0x45d9f3bu;
        x = (x >> 16) ^ x;
        return float(x) / 4294967295.0;
}

void main() {
        int index = int(gl_GlobalInvocationID.x);
        if (index >= params.width * params.width) {
                return;
        }
        ivec2 pixel_cord = ivec2(index % params.width, index / params.width);
        uint id = uint(index);

        Droplet d = droplets[id];

        // Spawn Droplet
        if (d.water <= 0.01 || d.pos.x < 1.0 || d.pos.x >= float(params.width - 2) || d.pos.y < 1.0 || d.pos.y >= float(params.width - 2)) {
                //if (d.sediment > 0.0) {
                //ivec2 p = ivec2(floor(d.pos));
                //if (p.x >= 0 && p.y >= 0 && p.x < params.width && p.y < params.width) {
                //heights[get_index(p.x, p.y)] += d.sediment;
                // }
                //}
                float rx = hash(id * 7843u + uint(params.seed) * 1664525u);
                float ry = hash(id * 9127u + uint(params.seed) * 22695477u);
                ivec2 img_size = imageSize(input_heightmap);
                d.pos = vec2(1.0 + rx * (float(img_size.x) - 3.0), 1.0 + ry * (float(img_size.y) - 3.0));
                d.dir = vec2(0.0);
                d.speed = 1.0;
                d.water = 1.0;
                d.sediment = 0.0;
        }

        // Erosion
        for (int step = 0; step < params.steps; step++) {
                ivec2 coordInt = ivec2(floor(d.pos));
                vec2 fracCord = fract(d.pos);

                if (coordInt.x < 1 || coordInt.x >= params.width - 2 || coordInt.y < 1 || coordInt.y >= params.width - 2) {
                        break;
                }

                // Compute gradient of 4 neighbours
                float h00 = heights[get_index(coordInt.x, coordInt.y)];
                float h10 = heights[get_index(coordInt.x + 1, coordInt.y)];
                float h01 = heights[get_index(coordInt.x, coordInt.y + 1)];
                float h11 = heights[get_index(coordInt.x + 1, coordInt.y + 1)];

                float gradX = (h10 - h00) * (1.0 - fracCord.y) + (h11 - h01) * fracCord.y;
                float gradY = (h01 - h00) * (1.0 - fracCord.x) + (h11 - h10) * fracCord.x;

                float h_center = mix(mix(h00, h10, fracCord.x), mix(h01, h11, fracCord.x), fracCord.y);

                // Move droplets down slope
                d.dir = d.dir * params.inertia - vec2(gradX, gradY) * (1.0 - params.inertia);
                if (length(d.dir) > 0.0001) {
                        d.dir = normalize(d.dir);
                }

                d.pos += d.dir;

                ivec2 newCoordInt = ivec2(floor(d.pos));
                vec2 newFracCoord = fract(d.pos);

                if (newCoordInt.x < 1 || newCoordInt.x >= params.width - 2 || newCoordInt.y < 1 || newCoordInt.y >= params.width - 2) {
                        break;
                }

                float nh00 = heights[get_index(newCoordInt.x, newCoordInt.y)];
                float nh10 = heights[get_index(newCoordInt.x + 1, newCoordInt.y)];
                float nh01 = heights[get_index(newCoordInt.x, newCoordInt.y + 1)];
                float nh11 = heights[get_index(newCoordInt.x + 1, newCoordInt.y + 1)];
                float h_new = mix(mix(nh00, nh10, newFracCoord.x), mix(nh01, nh11, newFracCoord.x), newFracCoord.y);

                float deltaH = h_new - h_center;

                float sedimentCapacity = max(-deltaH * d.speed * d.water * params.sedimentCapacityFactor, params.minSedimentCapacity);

                float w00 = (1.0 - fracCord.x) * (1.0 - fracCord.y);
                float w10 = fracCord.x * (1.0 - fracCord.y);
                float w01 = (1.0 - fracCord.x) * fracCord.y;
                float w11 = fracCord.x * fracCord.y;

                if (d.sediment > sedimentCapacity || deltaH > 0.0) {
                        float amountToDeposit = (deltaH > 0.0) ? min(deltaH, d.sediment) : (d.sediment - sedimentCapacity) * params.depositionSpeed;
                        d.sediment -= amountToDeposit;

                        heights[get_index(coordInt.x, coordInt.y)] += amountToDeposit * w00;
                        heights[get_index(coordInt.x + 1, coordInt.y)] += amountToDeposit * w10;
                        heights[get_index(coordInt.x, coordInt.y + 1)] += amountToDeposit * w01;
                        heights[get_index(coordInt.x + 1, coordInt.y + 1)] += amountToDeposit * w11;
                }
                else {
                        float amountToErode = min(min((sedimentCapacity - d.sediment) * params.erosionSpeed, -deltaH), 0.01);
                        d.sediment += amountToErode;

                        heights[get_index(coordInt.x, coordInt.y)] -= amountToErode * w00;
                        heights[get_index(coordInt.x + 1, coordInt.y)] -= amountToErode * w10;
                        heights[get_index(coordInt.x, coordInt.y + 1)] -= amountToErode * w01;
                        heights[get_index(coordInt.x + 1, coordInt.y + 1)] -= amountToErode * w11;
                }
                d.speed = sqrt(max(0.0, d.speed * d.speed - deltaH * params.gravity));
                d.water *= (1.0 - params.evaporationRate);
        }
        droplets[id] = d;
}
