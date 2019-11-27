function td = buildTrialData(trials, meta, varargin)
  p = inputParser();
  p.addParameter('includeSpikeData', true, @islogical);
  p.addParameter('includeWaveforms', true, @islogical);
  p.addParameter('includeContinuousNeuralData', true, @islogical);
  p.KeepUnmatched = false;
  p.parse(varargin{:});

  tdi = MatUdpTrialDataInterfaceV11(trials, meta);
  tdi.includeSpikeData = p.Results.includeSpikeData;
  tdi.includeWaveforms = p.Results.includeWaveforms;
  tdi.includeContinuousNeuralData = p.Results.includeContinuousNeuralData;

  td = TrialData(tdi);
end