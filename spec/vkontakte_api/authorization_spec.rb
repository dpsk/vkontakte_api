require 'spec_helper'

describe VkontakteApi::Authorization do
  before(:each) do
    @app_id = double("App id")
    VkontakteApi.stub(:app_id).and_return(@app_id)
    @app_secret = double("App secret")
    VkontakteApi.stub(:app_secret).and_return(@app_secret)
    @redirect_uri = double("Redirect uri")
    VkontakteApi.stub(:redirect_uri).and_return(@redirect_uri)
    
    @url   = double("Authorization url")
    @token = double("Token")
    
    @auth_code          = double("Authorization code strategy", get_token: @token, authorize_url: @url)
    @implicit           = double("Implicit strategy",           authorize_url: @url)
    @client_credentials = double("Client credentials strategy", get_token: @token)
    
    @client = double("OAuth2::Client instance", auth_code: @auth_code, implicit: @implicit, client_credentials: @client_credentials)
    OAuth2::Client.stub(:new).and_return(@client)
    
    @auth = Object.new
    @auth.extend VkontakteApi::Authorization
  end
  
  describe "#authorization_url" do
    before(:each) do
      @auth.stub(:client).and_return(@client)
    end
    
    context "with a site type" do
      it "returns a valid authorization url" do
        @auth_code.should_receive(:authorize_url).with(redirect_uri: @redirect_uri)
        @auth.authorization_url(type: :site).should == @url
      end
    end
    
    context "with a client type" do
      it "returns a valid authorization url" do
        @implicit.should_receive(:authorize_url).with(redirect_uri: @redirect_uri)
        @auth.authorization_url(type: :client).should == @url
      end
    end
    
    context "given a redirect_uri" do
      it "prefers the given uri over VkontakteApi.redirect_uri" do
        redirect_uri = 'http://example.com/oauth/callback'
        @auth_code.should_receive(:authorize_url).with(redirect_uri: redirect_uri)
        @auth.authorization_url(redirect_uri: redirect_uri)
      end
    end
    
    context "given a scope" do
      it "sends it to VkontakteApi::Utils.flatten_argument" do
        scope = double("Scope")
        flat_scope = double("Flat scope")
        
        VkontakteApi::Utils.should_receive(:flatten_argument).with(scope).and_return(flat_scope)
        @auth_code.should_receive(:authorize_url).with(redirect_uri: @redirect_uri, scope: flat_scope)
        @auth.authorization_url(scope: scope)
      end
    end
  end
  
  describe "#authorize" do
    context "with a site type" do
      before(:each) do
        @code = double("Authorization code")
        @auth_code.stub(:get_token).and_return(@token)
      end
      
      it "gets the token" do
        @auth_code.should_receive(:get_token).with(@code, redirect_uri: @redirect_uri)
        @auth.authorize(type: :site, code: @code)
      end
    end
    
    context "with an app_server type" do
      it "gets the token" do
        @client_credentials.should_receive(:get_token).with({ redirect_uri: @redirect_uri }, subject::OPTIONS[:client_credentials])
        @auth.authorize(type: :app_server)
      end
    end
    
    context "with an unknown type" do
      it "raises an ArgumentError" do
        expect {
          @auth.authorize(type: :unknown)
        }.to raise_error(ArgumentError)
      end
    end
    
    it "builds a VkontakteApi::Client instance with the received token" do
      client = double("VkontakteApi::Client instance")
      VkontakteApi::Client.should_receive(:new).with(@token).and_return(client)
      @auth.authorize.should == client
    end
  end
  
  describe "#client" do
    it "creates and returns an OAuth2::Client instance" do
      OAuth2::Client.should_receive(:new).with(@app_id, @app_secret, subject::OPTIONS[:client])
      @auth.send(:client).should == @client
    end
    
    it "caches the result" do
      OAuth2::Client.should_receive(:new).once
      5.times { @auth.send(:client) }
    end
  end
end
