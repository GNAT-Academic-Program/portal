#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <iostream>
#include <string>

int main()
{
    if (SDL_Init(SDL_INIT_VIDEO) != 0)
    {
        std::cout << "SDL Error: " << SDL_GetError() << std::endl;
        return 1;
    }
    if (TTF_Init() != 0)
    {
        std::cout << "TTF Error: " << TTF_GetError() << std::endl;
        return 1;
    }

  
    SDL_Window* window = SDL_CreateWindow(
        "Demo",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        800,
        600,
        SDL_WINDOW_SHOWN
    );

    SDL_Renderer* renderer = SDL_CreateRenderer(
        window,
        -1,
        SDL_RENDERER_ACCELERATED
    );

    TTF_Font* font = TTF_OpenFont(
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
        32
    );

    if (font == nullptr)
    {
        std::cout << "Font Error: " << TTF_GetError() << std::endl;
        return 1;
    }

    bool running = true;
    SDL_Event event;

    std::string text = "Press a key";

    while (running)
    {
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_QUIT)
            {
                running = false;
            }

            if (event.type == SDL_KEYDOWN)
            {
                text = "Key Pressed: ";
                text += SDL_GetKeyName(event.key.keysym.sym);

                if (event.key.keysym.sym == SDLK_ESCAPE)
                {
                    running = false;
                }
            }
        }

        SDL_SetRenderDrawColor(renderer, 30, 30, 30, 255);
        SDL_RenderClear(renderer);
      
        SDL_Color color = {255, 255, 255, 255};

        SDL_Surface* surface =
            TTF_RenderText_Solid(font, text.c_str(), color);

        SDL_Texture* texture =
            SDL_CreateTextureFromSurface(renderer, surface);

        SDL_Rect textRect;
        textRect.x = 50;
        textRect.y = 50;
        textRect.w = surface->w;
        textRect.h = surface->h;

        SDL_RenderCopy(
            renderer,
            texture,
            nullptr,
            &textRect
        );

        SDL_FreeSurface(surface);
        SDL_DestroyTexture(texture);

        SDL_RenderPresent(renderer);
    }

    TTF_CloseFont(font);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);

    TTF_Quit();
    SDL_Quit();

    return 0;
}
