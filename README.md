Realtime version of [libdjwaveform](https://github.com/turbo/libdjwaveform) - rendering Serato-style spectral waveforms using Love2D 12.0 compute shaders.

* launch the main app using `love .`
* use space to pause/play the mix of all stems
* use scroll to zoom each waveform
* use click-and-drag to pan each waveform

This makes use of direct SoundData to Buffer copies by packing two 16bit samples into one 32bit uint for the FFT SSBO.

Learn more about Love 12 compute shaders in my blog series: https://code.tc/blog/?q=love2d