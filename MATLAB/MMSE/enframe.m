 function [f,t,w]=enframe(x,win,hop,m,fs)
 %ENFRAME split signal up into (overlapping) frames: one per row. [F,T]=(X,WIN,HOP)
 %
 % Usage:  (1) f=enframe(x,n)                          % split into frames of length n
 %         (2) f=enframe(x,hamming(n,'periodic'),n/4)  % use a 75% overlapped Hamming window of length n
 %         (3) calculate spectrogram in units of power per Hz
 %
 %               W=hamming(NW);                      % analysis window (NW = fft length)
 %               P=enframe(S,W,HOP,'sdp',FS);        % computer first half of PSD (HOP = frame increment in samples)
 %
 %         (3) frequency domain frame-based processing:
 %
 %               S=...;                              % input signal
 %               OV=2;                               % overlap factor of 2 (4 is also often used)
 %               NW=160;                          % DFT window length
 %               W=sqrt(hamming(NW,'periodic'));     % omit sqrt if OV=4
 %               [F,T,WS]=enframe(S,W,1/OV,'fa');      % do STFT: one row per time frame, +ve frequencies only
 %               ... process frames ...
 %               X=overlapadd(irfft(F,NW,2),WS,HOP);  % reconstitute the time waveform with scaled window (omit "X=" to plot waveform)
 %
 %  Inputs:   x    input signal
 %          win    window or window length in samples
 %          hop    frame increment or hop in samples or fraction of window [window length]
 %            m    mode input:
 %                  'z'  zero pad to fill up final frame
 %                  'r'  reflect last few samples for final frame
 %                  'A'  calculate the t output as the centre of mass
 %                  'E'  calculate the t output as the centre of energy
 %                  'f'  perform a 1-sided dft on each frame (like rfft)
 %                  'F'  perform a 2-sided dft on each frame using fft
 %                  'p'  calculate the 1-sided power/energy spectrum of each frame
 %                  'P'  calculate the 2-sided power/energy spectrum of each frame
 %                  'a'  scale window to give unity gain with overlap-add
 %                  's'  scale window so that power is preserved: sum(mean(enframe(x,win,hop,'sp'),1))=mean(x.^2)
 %                  'S'  scale window so that total energy is preserved: sum(sum(enframe(x,win,hop,'Sp')))=sum(x.^2)
 %                  'd'  make options 's' and 'S' give power/energy per Hz: sum(mean(enframe(x,win,hop,'sp'),1))*fs/length(win)=mean(x.^2)
 %           fs    sample frequency (only needed for 'd' option) [1]
 %
 % Outputs:   f    enframed data - one frame per row
 %            t    fractional time in samples at the centre of each frame
 %                 with the first sample being 1.
 %            w    window function used
 %
 % By default, the number of frames will be rounded down to the nearest
 % integer and the last few samples of x() will be ignored unless its length
 % is lw more than a multiple of hop. If the 'z' or 'r' options are given,
 % the number of frame will instead be rounded up and no samples will be ignored.
 %
 
 % Bugs/Suggestions:
 %  (1) Possible additional mode options:
 %        'u'  modify window for first and last few frames to ensure WOLA
 %        'a'  normalize window to give a mean of unity after overlaps
 %        'e'  normalize window to give an energy of unity after overlaps
 %        'wm' use Hamming window
 %        'wn' use Hanning window
 %        'x'  hoplude all frames that hoplude any of the x samples
 
 %       Copyright (C) Mike Brookes 1997-2 %      Version: $Id: enframe.m 9529 202-25 19:08:56Z dmb $
 %
 %   VOICEBOX is a MATLAB toolbox for speech processing.
 %   Home page: http://www.ee.ic.ac.uk/hp/staff/dmb/voicebox/voicebox.html
 %
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 %   This program is free software; you can redistribute it and/or modify
 %   it under the terms of the GNU General Public License as published by
 %   the Free Software Foundation; either version 2 of the License, or
 %   (at your option) any later version.
 %
 %   This program is distributed in the hope that it will be useful,
 %   but WITHOUT ANY WARRANTY; without even the implied warranty of
 %   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 %   GNU General Public License for more details.
 %
 %   You can obtain a copy of the GNU General Public License from
 %   http://www.gnu.org/copyleft/gpl.html or by writing to
 %   Free Software Foundation, Inc.,675 Mass Ave, Cambridge, MA 02139, USA.
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
 nx=length(x(:));
 if nargin<2 || isempty(win)
     win=nx;
 end
 if nargin<4 || isempty(m)
     m='';
 end
 nwin=length(win);
 if nwin == 1
     lw = win;
     w = ones(1,lw);
 else
     lw = nwin;
     w = win(:).';
 end
 if (nargin < 3) || isempty(hop)
     hop = lw; % if no hop given, make non-overlapping
 elseif hop<1
     hop=lw*hop;
end
if any(m=='a')
     w=w*sqrt(hop/sum(w.^2)); % scale to give unity gain for overlap-add
 elseif any(m=='s')
     w=w/sqrt(w*w'*lw);
 elseif any(m=='S')
     w=w/sqrt(w*w'*lw/hop);
 end
 if any(m=='d') % scale to give power/energy densities
     if nargin<5 || isempty(fs)
         w=w*sqrt(lw);
     else
         w=w*sqrt(lw/fs);
     end
 end
 nli=nx-lw+hop;
 nf = max(fix(nli/hop),0);   % number of full frames
 na=nli-hop*nf+(nf==0)*(lw-hop);       % number of samples left over
 fx=nargin>3 && (any(m=='z') || any(m=='r')) && na>0; % need an extra row
 f=zeros(nf+fx,lw);
 indf= hop*(0:(nf-1)).';
 inds = (1:lw);
 if fx
     f(1:nf,:) = x(indf(:,ones(1,lw))+inds(ones(nf,1),:));
     if any(m=='r')
         ix=1+mod(nf*hop:nf*hop+lw-1,2*nx);
         f(nf+1,:)=x(ix+(ix>nx).*(2*nx+1-2*ix));
     else
         f(nf+1,1:nx-nf*hop)=x(1+nf*hop:nx);
     end
     nf=size(f,1);
 else
     f(:) = x(indf(:,ones(1,lw))+inds(ones(nf,1),:));
 end
 if (nwin > 1)   % if we have a non-unity window
     f = f .* w(ones(nf,1),:);
 end
 if any(lower(m)=='p') % 'pP' = calculate the power spectrum
     f=fft(f,[],2);
     f=real(f.*conj(f));
     if any(m=='p')
         imx=fix((lw+1)/2); % highest replicated frequency
         f(:,2:imx)=f(:,2:imx)+f(:,lw:-1:lw-imx+2);
         f=f(:,1:fix(lw/2)+1);
     end
 elseif any(lower(m)=='f') % 'fF' = take the DFT
     f=fft(f,[],2);
     if any(m=='f')
         f=f(:,1:fix(lw/2)+1);
     end
 end
 if nargout>1
     if any(m=='E')
         t0=sum((1:lw).*w.^2)/sum(w.^2);
     elseif any(m=='A')
         t0=sum((1:lw).*w)/sum(w);
     else
         t0=(1+lw)/2;
     end
     t=t0+hop*(0:(nf-1)).';
 end
 
