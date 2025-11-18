# FM Radio

- Category: Eavesdropping
- Level: Easy
- Flag: MR{fmradiotransmitssoundbyvaryingfrequency}

## Description

Raw iq file of a FM Radio signal is provided.
User should be use the file to get the original voice. 
The voice tells the flag.

- audio rate: 48khz
    - standard for high-quality digital audio (professional broadcast)
- Quadrature, Sample rate: 240khz
    - Usual fm radio bandwidth is 200khz.
    - Used near 200khz for the iq file. (Setting it to 200khz works too. Don't need to be precise.)

## Files

- **flag.iq: Provided iq file**
- flag48.wav: Original wav file (samp rate 480khz)

- fm_receive.grc: Solution gnu radio file
- fm_transmit.grc: gnu radio file used for generating flag.iq

