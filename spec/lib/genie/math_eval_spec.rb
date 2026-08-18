# frozen_string_literal: true

require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::MathEval do
  def evl(expr)
    described_class.evaluate(expr)
  end

  describe '.evaluate' do
    it 'handles the numeric fast path' do
      expect(evl('42')).to eq(42.0)
      expect(evl(' 3.5 ')).to eq(3.5)
    end

    it 'applies standard precedence' do
      expect(evl('2 + 3 * 4')).to eq(14.0)
      expect(evl('(2 + 3) * 4')).to eq(20.0)
      expect(evl('10 - 2 - 3')).to eq(5.0) # left associative
    end

    it 'treats ^ as LEFT-associative (Genie quirk)' do
      expect(evl('2 ^ 3 ^ 2')).to eq(64.0) # (2^3)^2, not 2^(3^2)=512
      expect(evl('2 ^ 10')).to eq(1024.0)
    end

    it 'supports unary minus' do
      expect(evl('-5 + 3')).to eq(-2.0)
      expect(evl('3 * -2')).to eq(-6.0)
    end

    it 'does integer division truncating toward zero' do
      expect(evl('7 \\ 2')).to eq(3.0)
      expect(evl('-7 \\ 2')).to eq(-3.0) # trunc toward zero, not floor (-4)
    end

    it 'takes modulo with the sign of the dividend' do
      expect(evl('-5 % 3')).to eq(-2.0)
      expect(evl('5 % 3')).to eq(2.0)
    end

    it 'computes factorial (postfix !)' do
      expect(evl('5 !')).to eq(120.0)
      expect(evl('0 !')).to eq(1.0)
      expect(evl('1 !')).to eq(1.0)
    end

    it 'exposes constants' do
      expect(evl('pi')).to be_within(1e-12).of(Math::PI)
      expect(evl('e')).to be_within(1e-12).of(Math::E)
    end

    it 'treats log as base-10 and ln as natural (Genie quirk)' do
      expect(evl('log(1000)')).to be_within(1e-9).of(3.0)
      expect(evl('log10(1000)')).to be_within(1e-9).of(3.0)
      expect(evl('ln(e)')).to be_within(1e-9).of(1.0)
    end

    it 'supports the function library' do
      expect(evl('sqrt(16)')).to eq(4.0)
      expect(evl('abs(-7)')).to eq(7.0)
      expect(evl('floor(3.9)')).to eq(3.0)
      expect(evl('ceiling(3.1)')).to eq(4.0)
      expect(evl('max(3, 7, 5)')).to eq(7.0)
      expect(evl('min(3, 7, 5)')).to eq(3.0)
      expect(evl('neg(4)')).to eq(-4.0)
    end

    it 'rounds using banker\'s rounding' do
      expect(evl('round(2.5)')).to eq(2.0)
      expect(evl('round(3.5)')).to eq(4.0)
      expect(evl('round(3.14159, 2)')).to eq(3.14)
    end

    it 'raises Error on malformed expressions' do
      expect { evl('') }.to raise_error(Lich::Genie::Error)
      expect { evl('2 +') }.to raise_error(Lich::Genie::Error)
      expect { evl('(2 + 3') }.to raise_error(Lich::Genie::Error)
    end
  end
end
