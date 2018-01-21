shared_examples_for 'interactor enabled' do
  it 'enables the interactor' do
    expect(described_class::Interactor).to receive(:new)
    described_class.setup_interactor
  end
end

shared_examples_for 'interactor disabled' do
  it 'disables the interactor' do
    expect(described_class::Interactor).not_to receive(:new)
    described_class.setup_interactor
  end
end

shared_examples_for 'notifier enabled' do
  it 'enables the notifier' do
    expect(described_class::Notifier).to receive(:turn_on)
    described_class.setup_notifier
  end
end

shared_examples_for 'notifier disabled' do
  it 'disables the notifier' do
    expect(described_class::Notifier).to receive(:turn_off)
    described_class.setup_notifier
  end
end
