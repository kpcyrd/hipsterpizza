class BasketController < ApplicationController
  include CookieHelper

  before_action :require_basket, except: [:new, :create, :find]
  before_filter :ensure_admin, except: [:new, :create, :find, :show, :share,
                                        :delivery_arrived, :pdf]


  PIZZADE_URL_MODIFIERS = { knddomain: 1, noflash: 1 }

  def new
    # if there’s an editable basket and we are in single basket mode,
    # redirect directly to basket instead of creating new one
    if PINNING['single_basket_mode']
      @basket = Basket.find_editable
      return redirect_to @basket unless @basket.nil?
    end

    fields = %w(name url fax)
    if all_pinned?(fields)
      copy_pinned_to_params(fields)
      return create
    end

    cookie_set(:mode, :pizzade_basket_new)

    if PINNING['shop_url']
      without_question_mark = PINNING['shop_url_params'].to_s.sub(/\A\?/, '')
      query = Rack::Utils.parse_nested_query(without_question_mark)
      query = query.merge(PIZZADE_URL_MODIFIERS)

      redirect_to "#{PINNING['shop_url']}?#{query.to_param}"
    else
      redirect_to root_service_path(:pizzade)
    end
  end

  def create
    basket = Basket.create(params.permit(:shop_name, :shop_url, :shop_fax, :shop_url_params))

    if basket.errors.any?
      msgs = errors_to_fake_list(basket)
      flash[:error] = t('basket.controller.create.errors', messages: msgs)
      return redirect_to root_path
    end

    cookie_set(:is_admin, true)

    if PINNING['single_basket_mode']
      redirect_to basket
    else
      redirect_to share_basket_path(basket.uid)
    end
  end

  def show
    @order = Order.where(basket_id: @basket.id, nick: @nick).first

    respond_to do |format|
      format.html

      format.js do
        find_changes
        head :no_content unless @basket_changed || @order_changed
      end

      format.svg  do
        render qrcode: basket_path(@basket), level: :l, unit: 6, offset: 10
      end
    end
  end

  def unsubmit
    @basket.update_attribute(:submitted, nil)
    flash[:info] = t 'basket.controller.reopened'
    redirect_to @basket
  end

  def set_submit_time
    @basket.update!(submitted: Time.now, sha_address: params[:sha_address])
    redirect_to @basket
  end

  def delivery_arrived
    begin
      @basket.update_attribute(:arrival, Time.parse(params[:arrival]))
      render json: { reload: true, disable: true }
    rescue ArgumentError, TypeError
      @basket.update_attribute(:arrival, Time.now)
      flash[:error] = t 'basket.controller.invalid_time'
      render json: { error: flash[:error] }
    end
  end

  def share
  end

  def toggle_cancelled
    if not @basket.toggle(:cancelled).save(validate: false)
      flash[:error] = t 'toggle_failed'
    elsif @basket.cancelled?
      flash[:warn] = t 'basket.controller.group_order.cancelled'
    else
      flash[:success] = t 'basket.controller.group_order.reenabled'
    end
    redirect_to @basket
  end

  def pdf
    @fax_config = load_fax_config
    fn = @basket.fax_filename
    response.headers['Content-Disposition'] = %(INLINE; FILENAME="#{fn}")
    response.headers['Content-Type'] = 'application/pdf'
    render 'fax.pdf'
  end

  private

  def ensure_admin
    return if view_context.admin?
    flash[:error] = t 'basket.controller.not_admin'
    redirect_to @basket
  end

  def all_pinned?(fields)
    fields.all? { |f| PINNING["shop_#{f}"] }
  end

  def copy_pinned_to_params(fields)
    fields.each do |f|
      f = "shop_#{f}"
      params[f.to_sym] = PINNING[f]
    end
  end

  # detects if @basket or @order have been changed compared to the timestamps
  # in the params (ts_basket and ts_order). It considers a deleted order as
  # newer if it was present before.
  def find_changes
    ts_basket = (params[:ts_basket] || 0).to_i
    @basket_changed = ts_basket < @basket.updated_at.to_i

    ts_option = (params[:ts_order] || 0).to_i
    order_deleted = @order.nil? && ts_option != 0
    order_updated = @order && ts_option < @order.updated_at.to_i
    @order_changed = order_deleted || order_updated
  end
end
